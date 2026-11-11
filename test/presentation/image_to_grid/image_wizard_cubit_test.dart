import 'dart:async';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_decoder.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_runner.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/use_cases/create_pattern_from_image.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_cubit.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_state.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_image_masks.dart';
import '../../support/fake_image_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_settings_repository.dart';

/// Запуск конвейера, который отвечает по сигналу теста: так видно, какой расчёт к чему относится.
class _ControlledRunner implements ImageToGridRunner {
  final List<ImageToGridRequest> requests = <ImageToGridRequest>[];
  final List<Completer<GeneratedPattern>> completers = <Completer<GeneratedPattern>>[];

  @override
  Future<GeneratedPattern> run(ImageToGridRequest request) {
    requests.add(request);
    final Completer<GeneratedPattern> completer = Completer<GeneratedPattern>();
    completers.add(completer);
    return completer.future;
  }
}

class _FakeDecoder implements ImageDecoder {
  Failure? failure;
  int calls = 0;

  @override
  Future<Result<SourceImage>> decode(Uint8List bytes, {int maxSide = 1024}) async {
    calls++;
    if (failure != null) return Err<SourceImage>(failure!);
    return Success<SourceImage>(SourceImage.solid(width: 20, height: 40, r: 200, g: 10, b: 10));
  }
}

GeneratedPattern _pattern(int marker) => GeneratedPattern(
  grid: Grid.fromCells(width: 2, height: 1, cells: const <int>[1, 1]),
  palette: <PaletteEntry>[PaletteEntry(rgb: Rgb(marker, 0, 0))],
);

void main() {
  late FakeBookImageSource source;
  late FakeImageProcessor processor;
  late _FakeDecoder decoder;
  late _ControlledRunner runner;
  late FakeImageMasks masks;
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;
  late FakeSettingsRepository settings;
  late FakeCatalogRepository catalog;
  late ImageWizardCubit cubit;

  ImageWizardCubit build({Duration debounce = const Duration(milliseconds: 300)}) {
    final FakeIdGenerator ids = FakeIdGenerator();
    return ImageWizardCubit(
      source: source,
      processor: processor,
      decoder: decoder,
      runner: runner,
      masks: masks,
      catalog: catalog,
      settings: settings,
      createPattern: CreatePatternFromImage(
        CreateGridPattern(
          createProject: CreateProject(repository: projects, ids: ids, clock: FakeClock(DateTime.utc(2026))),
          projects: projects,
          patterns: patterns,
          ids: ids,
        ),
      ),
      debounce: debounce,
    );
  }

  PickedBookFile photo([String name = 'Розы.jpg']) =>
      PickedBookFile(name: name, bytes: Uint8List.fromList(<int>[1, 2]));

  setUp(() {
    source = FakeBookImageSource();
    processor = FakeImageProcessor();
    decoder = _FakeDecoder();
    runner = _ControlledRunner();
    masks = FakeImageMasks();
    projects = FakeProjectRepository();
    patterns = FakeGridPatternRepository();
    settings = FakeSettingsRepository();
    catalog = FakeCatalogRepository(<CatalogColor>[]);
  });

  /// Выбирает фото и отвечает на первый расчёт.
  Future<void> openPhoto() async {
    source.next = Success<List<PickedBookFile>>(<PickedBookFile>[photo()]);
    await cubit.pickPhotos();
    await Future<void>.delayed(Duration.zero);
    runner.completers.last.complete(_pattern(1));
    await Future<void>.delayed(Duration.zero);
  }

  group('маски (T48)', () {
    setUp(() => cubit = build(debounce: Duration.zero));
    tearDown(() => cubit.close());

    Future<void> pick() async {
      source.next = Success<List<PickedBookFile>>(<PickedBookFile>[photo()]);
      await cubit.pickPhotos();
      await Future<void>.delayed(Duration.zero);
    }

    ImageMaskSet withFace() => ImageMaskSet(
      width: 20,
      height: 40,
      faces: const <DetectedFace>[
        DetectedFace(bounds: NormalizedRect(left: 0.25, top: 0.25, right: 0.75, bottom: 0.5)),
      ],
    );

    test('запрашивает маски у размера картинки конвейера и кладёт маску важности в запрос', () async {
      masks.result = withFace();
      await pick();
      expect(masks.calls, <({int width, int height})>[(width: 20, height: 40)]);
      expect(cubit.state.hasMasks, isTrue);
      final Float32List importance = runner.requests.single.importance!;
      expect(importance, hasLength(20 * 40));
      expect(importance[12 * 20 + 10], 4); // середина лица
      expect(importance[0], 0.5); // фон
    });

    test('«Выделять главное» выключено — запрос без маски важности', () async {
      masks.result = withFace();
      await pick();
      runner.completers.last.complete(_pattern(1));
      await Future<void>.delayed(Duration.zero);
      cubit.setUseMasks(value: false);
      await Future<void>.delayed(Duration.zero);
      expect(runner.requests.last.importance, isNull);
      cubit.setUseMasks(value: true);
      await Future<void>.delayed(Duration.zero);
      expect(runner.requests.last.importance, isNotNull);
    });

    test('ошибка Vision — мастер работает без масок', () async {
      masks.failure = const UnexpectedFailure('нет Vision');
      await pick();
      expect(cubit.state.step, ImageWizardStep.edit);
      expect(cubit.state.hasMasks, isFalse);
      expect(runner.requests.single.importance, isNull);
    });

    test('исключение из платформы не ломает мастер', () async {
      masks.throwing = StateError('сбой');
      await pick();
      expect(cubit.state.step, ImageWizardStep.edit);
      expect(runner.requests.single.importance, isNull);
    });

    test('поздний ответ масок для прошлой обрезки не попадает в запрос', () async {
      await pick();
      final Completer<void> gate = Completer<void>();
      masks
        ..result = withFace()
        ..gate = gate.future;
      final Future<void> first = cubit.rotate();
      await Future<void>.delayed(Duration.zero);
      masks
        ..gate = null
        ..result = ImageMaskSet.empty(width: 20, height: 40);
      await cubit.rotate();
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.quarterTurns, 2);
      expect(cubit.state.hasMasks, isFalse);
      expect(runner.requests.last.importance, isNull);
    });

    test('пустой набор масок: переключатель не нужен, всё одинаково важно', () async {
      await pick();
      expect(cubit.state.hasMasks, isFalse);
      expect(runner.requests.single.importance, isNull);
    });
  });

  group('выбор картинки', () {
    setUp(() => cubit = build(debounce: Duration.zero));
    tearDown(() => cubit.close());

    test('начинает с выбора источника', () {
      expect(cubit.state.step, ImageWizardStep.pickSource);
      expect(cubit.state.canSave, isFalse);
    });

    test('после выбора фото открывает правку, берёт имя из файла и считает схему', () async {
      source.next = Success<List<PickedBookFile>>(<PickedBookFile>[photo()]);
      await cubit.pickPhotos();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.step, ImageWizardStep.edit);
      expect(cubit.state.name, 'Розы');
      expect(cubit.state.calculating, isTrue);
      expect(runner.requests, hasLength(1));
      runner.completers.single.complete(_pattern(1));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.calculating, isFalse);
      expect(cubit.state.preview, isNotNull);
      expect(cubit.state.canSave, isTrue);
    });

    test('закрытый выбор ничего не меняет', () async {
      await cubit.takePhoto();
      expect(cubit.state.step, ImageWizardStep.pickSource);
      expect(cubit.state.opening, isFalse);
      expect(cubit.state.problem, isNull);
      expect(source.calls, <String>['camera']);
    });

    test('источник недоступен — понятная ошибка', () async {
      source.next = const Err<List<PickedBookFile>>(StorageFailure('нет доступа'));
      await cubit.pickFiles();
      expect(cubit.state.problem, ImageWizardProblem.sourceUnavailable);
      expect(cubit.state.opening, isFalse);
    });

    test('PDF не картинка: ошибка, остаёмся на выборе', () async {
      source.next = Success<List<PickedBookFile>>(<PickedBookFile>[
        PickedBookFile(name: 'книга.pdf', bytes: Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46])),
      ]);
      await cubit.pickFiles();
      expect(cubit.state.problem, ImageWizardProblem.unreadable);
      expect(cubit.state.step, ImageWizardStep.pickSource);
    });

    test('нечитаемая картинка — ошибка, остаёмся на выборе', () async {
      decoder.failure = const ValidationFailure('битая');
      source.next = Success<List<PickedBookFile>>(<PickedBookFile>[photo()]);
      await cubit.pickPhotos();
      expect(cubit.state.problem, ImageWizardProblem.unreadable);
      expect(cubit.state.step, ImageWizardStep.pickSource);
      expect(runner.requests, isEmpty);
    });
  });

  group('предпросмотр', () {
    test('быстрые правки подряд сливаются в один расчёт после паузы', () {
      fakeAsync((async) {
        cubit = build();
        source.next = Success<List<PickedBookFile>>(<PickedBookFile>[photo()]);
        unawaited(cubit.pickPhotos());
        async.flushMicrotasks();
        expect(runner.requests, hasLength(1)); // первый расчёт после выбора — сразу
        runner.completers.last.complete(_pattern(1));
        async.flushMicrotasks();

        cubit
          ..setColumns(50)
          ..setColumns(60)
          ..setColumns(70);
        async.elapse(const Duration(milliseconds: 200));
        expect(runner.requests, hasLength(1));
        expect(cubit.state.calculating, isTrue);
        async.elapse(const Duration(milliseconds: 200));
        expect(runner.requests, hasLength(2));
        expect(runner.requests.last.columns, 70);
        unawaited(cubit.close());
      });
    });

    test('устаревший расчёт отбрасывается, на экране схема последних параметров', () async {
      cubit = build(debounce: Duration.zero);
      addTearDown(cubit.close);
      await openPhoto();

      cubit.setColumns(50);
      cubit.setColumns(60);
      expect(runner.requests.map((r) => r.columns), <int>[40, 50, 60]);

      // Второй расчёт отвечает позже третьего, но уже никому не нужен.
      runner.completers[2].complete(_pattern(3));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.calculating, isFalse);
      expect(cubit.state.preview!.palette.single.rgb, const Rgb(3, 0, 0));

      runner.completers[1].complete(_pattern(2));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.preview!.palette.single.rgb, const Rgb(3, 0, 0));
    });

    test('пока идёт расчёт, прежний предпросмотр остаётся, а сохранить нельзя', () async {
      cubit = build(debounce: Duration.zero);
      addTearDown(cubit.close);
      await openPhoto();
      cubit.setMaxColors(5);
      expect(cubit.state.calculating, isTrue);
      expect(cubit.state.preview, isNotNull);
      expect(cubit.state.canSave, isFalse);
    });

    test('ошибка расчёта — сообщение, схему можно пересчитать правкой', () async {
      cubit = build(debounce: Duration.zero);
      addTearDown(cubit.close);
      await openPhoto();
      cubit.setDither(value: true);
      runner.completers.last.completeError(StateError('boom'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.problem, ImageWizardProblem.calculationFailed);
      expect(cubit.state.calculating, isFalse);
      expect(cubit.state.canSave, isFalse); // старая схема не соответствует новым параметрам
      cubit.setDither(value: false);
      expect(cubit.state.problem, isNull);
    });

    test('параметры попадают в запрос к конвейеру', () async {
      cubit = build(debounce: Duration.zero);
      addTearDown(cubit.close);
      await openPhoto();
      cubit
        ..setTechnique(Technique.peyote)
        ..setBeadSize(BeadSize.delica10)
        ..setColumns(30)
        ..setMaxColors(6)
        ..setPaletteSource(PaletteSource.free)
        ..setDither(value: true);
      final ImageToGridRequest request = runner.requests.last;
      expect(request.columns, 30);
      expect(request.maxColors, 6);
      expect(request.dither, isTrue);
      expect(request.metrics, BeadSize.delica10);
      expect(request.constraint.isFree, isTrue);
    });

    test('поворот и обрезка заново готовят картинку и пересчитывают схему', () async {
      cubit = build(debounce: Duration.zero);
      addTearDown(cubit.close);
      await openPhoto();
      await cubit.rotate();
      expect(cubit.state.quarterTurns, 1);
      expect(processor.calls.last.quarterTurns, 1);
      expect(runner.requests, hasLength(2));
      const CropRect crop = CropRect(left: 0.1, top: 0.1, right: 0.9, bottom: 0.9);
      await cubit.setCrop(crop);
      expect(processor.calls.last.crop, crop);
      expect(cubit.state.crop, crop);
      expect(runner.requests, hasLength(3));
      await cubit.rotate();
      expect(cubit.state.crop, CropRect.full); // рамка в повёрнутых осях сбрасывается
    });
  });

  group('каталог', () {
    test('считает подходящие цвета под размер бусины и бренд по умолчанию', () async {
      catalog = FakeCatalogRepository(<CatalogColor>[
        catalogColor('DB0010', 'Красный', '#C80A14'),
        catalogColor('T-1', 'Toho', '#00FF00', brand: 'Toho', series: 'Round'),
      ]);
      await settings.write(SettingKeys.defaultBeadBrand, 'Miyuki');
      cubit = build(debounce: Duration.zero);
      addTearDown(cubit.close);
      await cubit.start();
      expect(cubit.state.catalogColors, 1);
      expect(cubit.state.catalogMissing, isFalse);
      cubit.setBeadSize(BeadSize.delica15);
      expect(cubit.state.catalogColors, 0);
      expect(cubit.state.catalogMissing, isTrue);
      cubit.setPaletteSource(PaletteSource.free);
      expect(cubit.state.catalogMissing, isFalse);
    });

    test('запрос ограничивается цветами каталога выбранного бренда', () async {
      catalog = FakeCatalogRepository(<CatalogColor>[
        catalogColor('DB0010', 'Красный', '#C80A14'),
        catalogColor('T-1', 'Toho', '#00FF00', brand: 'Toho', series: 'Round'),
      ]);
      await settings.write(SettingKeys.defaultBeadBrand, 'Miyuki');
      cubit = build(debounce: Duration.zero);
      addTearDown(cubit.close);
      await cubit.start();
      await openPhoto();
      expect(runner.requests.last.constraint.candidates, hasLength(1));
    });
  });

  group('сохранение', () {
    setUp(() => cubit = build(debounce: Duration.zero));
    tearDown(() => cubit.close());

    test('создаёт проект и сообщает его id', () async {
      await openPhoto();
      cubit.setTechnique(Technique.brick);
      runner.completers.last.complete(_pattern(7));
      await Future<void>.delayed(Duration.zero);
      cubit.setName('Моя схема');
      await cubit.save();
      expect(cubit.state.step, ImageWizardStep.done);
      final Project project = projects.projects[cubit.state.projectId!]!;
      expect(project.name, 'Моя схема');
      expect(project.technique, Technique.brick);
      expect(patterns.byProject[project.id]!.palette.colorAt(1)!.rgb, const Rgb(7, 0, 0));
    });

    test('пока схема считается, сохранить нельзя', () async {
      await openPhoto();
      cubit.setColumns(60);
      await cubit.save();
      expect(cubit.state.step, ImageWizardStep.edit);
      expect(projects.projects, isEmpty);
    });

    test('пустое название — ошибка, проект не создаётся', () async {
      await openPhoto();
      cubit.setName('   ');
      await cubit.save();
      expect(cubit.state.problem, ImageWizardProblem.invalidName);
      expect(cubit.state.step, ImageWizardStep.edit);
      expect(projects.projects, isEmpty);
    });

    test('ошибка записи возвращает к правке с сообщением', () async {
      await openPhoto();
      patterns.failNextSave = const StorageFailure('диск');
      await cubit.save();
      expect(cubit.state.step, ImageWizardStep.edit);
      expect(cubit.state.problem, ImageWizardProblem.saveFailed);
      expect(cubit.state.canSave, isTrue);
    });
  });

  test('«до/после»: удержание показывает исходную картинку', () async {
    cubit = build(debounce: Duration.zero);
    addTearDown(cubit.close);
    await openPhoto();
    cubit.setComparing(value: true);
    expect(cubit.state.comparing, isTrue);
    cubit.setComparing(value: false);
    expect(cubit.state.comparing, isFalse);
  });
}
