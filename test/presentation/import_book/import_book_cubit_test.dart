import 'dart:async';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/image_pattern/use_cases/import_book_pattern.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/presentation/import_book/import_book_cubit.dart';
import 'package:beading/presentation/import_book/import_book_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_image_pattern.dart';
import '../../support/fake_project_repository.dart';

PickedBookFile _photo(String name, [int marker = 1]) =>
    PickedBookFile(name: name, bytes: Uint8List.fromList(<int>[0xFF, marker]));

final PickedBookFile _pdf = PickedBookFile(name: 'Розы.pdf', bytes: Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46]));

void main() {
  late FakeBookImageSource source;
  late FakePdfRasterizer rasterizer;
  late FakeProjectRepository projects;
  late FakeImagePatternRepository patterns;
  late FakeFileStore files;
  late FakeImageProcessor processor;
  late ImportBookCubit cubit;

  setUp(() {
    source = FakeBookImageSource();
    rasterizer = FakePdfRasterizer();
    projects = FakeProjectRepository();
    patterns = FakeImagePatternRepository();
    files = FakeFileStore();
    processor = FakeImageProcessor();
    final FakeIdGenerator ids = FakeIdGenerator();
    cubit = ImportBookCubit(
      source: source,
      rasterizer: rasterizer,
      importBookPattern: ImportBookPattern(
        createProject: CreateProject(repository: projects, ids: ids, clock: FakeClock(DateTime.utc(2026))),
        projects: projects,
        patterns: patterns,
        processor: processor,
        files: files,
        ids: ids,
      ),
    );
    addTearDown(cubit.close);
  });

  void picked(List<PickedBookFile> list) => source.next = Success<List<PickedBookFile>>(list);

  test('начинает с выбора источника', () {
    expect(cubit.state.step, ImportStep.pickSource);
    expect(cubit.state.pages, isEmpty);
  });

  test('каждый источник вызывает свой метод', () async {
    await cubit.takePhoto();
    await cubit.pickPhotos();
    await cubit.pickFiles();

    expect(source.calls, <String>['camera', 'photos', 'files']);
  });

  test('отмена выбора ничего не меняет', () async {
    picked(const <PickedBookFile>[]);

    await cubit.pickPhotos();

    expect(cubit.state.step, ImportStep.pickSource);
    expect(cubit.state.problem, isNull);
  });

  test('отказ в доступе показывает проблему и остаётся на выборе', () async {
    source.next = const Err<List<PickedBookFile>>(StorageFailure('denied'));

    await cubit.takePhoto();

    expect(cubit.state.step, ImportStep.pickSource);
    expect(cubit.state.problem, ImportProblem.sourceUnavailable);
  });

  test('фото попадают в список страниц, название — по имени файла', () async {
    picked(<PickedBookFile>[_photo('Браслет.heic'), _photo('p2.jpg', 2)]);

    await cubit.pickPhotos();

    expect(cubit.state.step, ImportStep.review);
    expect(cubit.state.pages, hasLength(2));
    expect(cubit.state.name, 'Браслет');
  });

  group('PDF', () {
    test('открывает выбор страниц с числом страниц документа', () async {
      picked(<PickedBookFile>[_pdf]);
      rasterizer.pages = 5;

      await cubit.pickFiles();

      expect(cubit.state.step, ImportStep.choosePdfPages);
      expect(cubit.state.pdfPageCount, 5);
      expect(cubit.state.name, 'Розы');
    });

    test('нечитаемый PDF — проблема, остаёмся на выборе', () async {
      picked(<PickedBookFile>[_pdf]);
      rasterizer.failure = const ValidationFailure('битый');

      await cubit.pickFiles();

      expect(cubit.state.step, ImportStep.pickSource);
      expect(cubit.state.problem, ImportProblem.pdfFailed);
    });

    test('пустой PDF — отдельная проблема, а не «не открылся»', () async {
      picked(<PickedBookFile>[_pdf]);
      rasterizer.pages = 0;

      await cubit.pickFiles();

      expect(cubit.state.problem, ImportProblem.pdfEmpty);
      expect(cubit.state.busy, isNull);
    });

    test('пока файл открывается, состояние занято; после — свободно', () async {
      picked(<PickedBookFile>[_pdf]);
      final List<ImportBusy?> seen = <ImportBusy?>[];
      final StreamSubscription<ImportBookState> sub = cubit.stream.listen((s) => seen.add(s.busy));

      await cubit.pickFiles();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(seen.first, ImportBusy.opening);
      expect(cubit.state.busy, isNull);
    });

    test('нумерация шагов: для PDF три, без него два', () async {
      expect(cubit.state.stepCount, 2);
      expect(cubit.state.stepNumber, 1);
      picked(<PickedBookFile>[_pdf]);
      await cubit.pickFiles();

      expect(cubit.state.stepCount, 3);
      expect(cubit.state.stepNumber, 2);
    });

    test('отмечает и снимает страницы, «все» и «снять»', () async {
      picked(<PickedBookFile>[_pdf]);
      await cubit.pickFiles();

      cubit
        ..togglePdfPage(1)
        ..togglePdfPage(2)
        ..togglePdfPage(1);
      expect(cubit.state.selectedPdfPages, <int>{2});
      cubit.selectAllPdfPages();
      expect(cubit.state.selectedPdfPages, <int>{0, 1, 2});
      cubit.clearPdfPages();
      expect(cubit.state.selectedPdfPages, isEmpty);
    });

    test('без выбранных страниц подтвердить нельзя', () async {
      picked(<PickedBookFile>[_pdf]);
      await cubit.pickFiles();

      await cubit.confirmPdfPages();

      expect(cubit.state.step, ImportStep.choosePdfPages);
      expect(cubit.state.problem, ImportProblem.noPages);
    });

    test('растеризует отмеченные страницы по порядку документа', () async {
      picked(<PickedBookFile>[_pdf]);
      await cubit.pickFiles();
      cubit
        ..togglePdfPage(2)
        ..togglePdfPage(0);

      await cubit.confirmPdfPages();

      expect(rasterizer.rendered.single, <int>[0, 2]);
      expect(cubit.state.step, ImportStep.review);
      expect(cubit.state.pages.map((p) => p.bytes.single), <int>[0, 2]);
    });

    test('сбой растеризации — проблема, выбор сохраняется', () async {
      picked(<PickedBookFile>[_pdf]);
      await cubit.pickFiles();
      cubit.togglePdfPage(0);
      rasterizer.failure = const ValidationFailure('нет');

      await cubit.confirmPdfPages();

      expect(cubit.state.step, ImportStep.choosePdfPages);
      expect(cubit.state.problem, ImportProblem.pdfFailed);
      expect(cubit.state.selectedPdfPages, <int>{0});
    });
  });

  group('проверка страниц', () {
    setUp(() async {
      picked(<PickedBookFile>[_photo('a.jpg'), _photo('b.jpg', 2), _photo('c.jpg', 3)]);
      await cubit.pickPhotos();
    });

    test('поворот идёт по кругу и сбрасывает рамку', () {
      final int id = cubit.state.pages.first.id;
      cubit
        ..setCrop(id, const CropRect(left: 0, top: 0, right: 0.5, bottom: 0.5))
        ..rotate(id);
      expect(cubit.state.pages.first.quarterTurns, 1);
      expect(cubit.state.pages.first.crop, CropRect.full);
      cubit
        ..rotate(id)
        ..rotate(id)
        ..rotate(id);
      expect(cubit.state.pages.first.quarterTurns, 0);
    });

    test('рамка относится только к своей странице', () {
      const CropRect crop = CropRect(left: 0.1, top: 0.1, right: 0.9, bottom: 0.9);
      cubit.setCrop(cubit.state.pages[1].id, crop);

      expect(cubit.state.pages.map((p) => p.crop), <CropRect>[CropRect.full, crop, CropRect.full]);
    });

    test('страницу можно переставить и убрать', () {
      cubit.move(0, 2);
      expect(cubit.state.pages.map((p) => p.bytes.last), <int>[2, 3, 1]);
      cubit.remove(cubit.state.pages.first.id);
      expect(cubit.state.pages.map((p) => p.bytes.last), <int>[3, 1]);
    });

    test('если убрали все страницы — снова выбор источника', () {
      for (final int id in cubit.state.pages.map((p) => p.id).toList()) {
        cubit.remove(id);
      }

      expect(cubit.state.step, ImportStep.pickSource);
    });

    test('«добавить ещё» сохраняет страницы и дописывает новые', () async {
      cubit.addMore();
      expect(cubit.state.step, ImportStep.pickSource);
      expect(cubit.state.pages, hasLength(3));
      picked(<PickedBookFile>[_photo('d.jpg', 4)]);

      await cubit.pickPhotos();

      expect(cubit.state.pages, hasLength(4));
      expect(cubit.state.name, 'a');
    });

    test('импорт создаёт проект выбранного ремесла и сообщает его id', () async {
      cubit
        ..setCraft(Craft.crossStitch)
        ..setName('Роза')
        ..rotate(cubit.state.pages.first.id);

      await cubit.submit();

      expect(cubit.state.step, ImportStep.done);
      final project = projects.projects[cubit.state.projectId]!;
      expect(project.name, 'Роза');
      expect(project.craft, Craft.crossStitch);
      expect(processor.calls.first.quarterTurns, 1);
      expect(patterns.byProject[project.id]!.pages, hasLength(3));
    });

    test('пустое название не отправляется', () async {
      cubit.setName('   ');

      await cubit.submit();

      expect(cubit.state.step, ImportStep.review);
      expect(cubit.state.problem, ImportProblem.emptyName);
      expect(projects.projects, isEmpty);
    });

    test('сбой сохранения возвращает на проверку без потери страниц', () async {
      files.failWritesAfter = 0;

      await cubit.submit();

      expect(cubit.state.step, ImportStep.review);
      expect(cubit.state.problem, ImportProblem.saveFailed);
      expect(cubit.state.pages, hasLength(3));
    });

    test('нечитаемая картинка — проблема unreadable', () async {
      processor.failure = const ValidationFailure('плохо');

      await cubit.submit();

      expect(cubit.state.problem, ImportProblem.unreadable);
    });
  });

  test('импорт без страниц — проблема noPages', () async {
    await cubit.submit();

    expect(cubit.state.problem, ImportProblem.noPages);
  });

  test('закрытие cubit во время выбора не вызывает ошибку при ответе источника', () async {
    final Completer<Result<List<PickedBookFile>>> reply = Completer<Result<List<PickedBookFile>>>();
    final ImportBookCubit closing = ImportBookCubit(
      source: _SlowSource(reply),
      rasterizer: rasterizer,
      importBookPattern: ImportBookPattern(
        createProject: CreateProject(
          repository: projects,
          ids: FakeIdGenerator(),
          clock: FakeClock(DateTime.utc(2026)),
        ),
        projects: projects,
        patterns: patterns,
        processor: processor,
        files: files,
        ids: FakeIdGenerator(),
      ),
    );

    final Future<void> pending = closing.pickPhotos();
    await closing.close();
    reply.complete(Success<List<PickedBookFile>>(<PickedBookFile>[_photo('a.jpg')]));

    await expectLater(pending, completes);
  });
}

class _SlowSource extends FakeBookImageSource {
  _SlowSource(this.reply);

  final Completer<Result<List<PickedBookFile>>> reply;

  @override
  Future<Result<List<PickedBookFile>>> pickPhotos() => reply.future;
}
