import 'dart:async';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/bead_finish_group.dart';
import 'package:beading/domain/catalog/bead_series.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/image_to_grid/background_stage.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
import 'package:beading/domain/image_to_grid/generation_stats.dart';
import 'package:beading/domain/image_to_grid/image_decoder.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_runner.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/ordered_dither_step.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/size_purpose.dart';
import 'package:beading/domain/image_to_grid/size_suggester.dart';
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

  int releases = 0;

  @override
  Future<void> release() async => releases++;
}

/// Запуск, который сразу отвечает: полные расчёты — схемой без метрик, пробы подсказки — корреляцией от ширины.
class _AutoRunner implements ImageToGridRunner {
  final List<ImageToGridRequest> requests = <ImageToGridRequest>[];

  /// Корреляция пробы по ширине; `null` — метрики нет.
  double? Function(int columns) correlation = (columns) => columns >= 60 ? 0.95 : 0.7;

  @override
  Future<GeneratedPattern> run(ImageToGridRequest request) async {
    requests.add(request);
    final GeneratedPattern base = _pattern(request.columns);
    if (!request.measure) return base;
    return GeneratedPattern(
      grid: base.grid,
      palette: base.palette,
      stats: GenerationStats(
        singleCells: 0,
        colorCount: 1,
        meanDeltaE: 0,
        stageTimes: const <String, Duration>{},
        lightnessCorrelation: correlation(request.columns),
      ),
    );
  }

  @override
  Future<void> release() async {}
}

class _FakeDecoder implements ImageDecoder {
  Failure? failure;
  int calls = 0;
  int? lastMaxSide;

  @override
  Future<Result<SourceImage>> decode(Uint8List bytes, {int maxSide = 1024}) async {
    calls++;
    lastMaxSide = maxSide;
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

  ImageWizardCubit build({Duration debounce = const Duration(milliseconds: 300), bool sizeHints = false}) {
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
      sizeHints: sizeHints,
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

  test('фото декодируется в 2048 пикселей по длинной стороне, а не в 1024 по умолчанию (T69)', () async {
    cubit = build(debounce: Duration.zero);
    await openPhoto();
    expect(decoder.lastMaxSide, wizardImageMaxSide);
    expect(wizardImageMaxSide, 2048);
    await cubit.close();
  });

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

    test('маска объекта и настройки фона и обводки попадают в запрос', () async {
      masks.result = ImageMaskSet(width: 20, height: 40, subject: Uint8List(20 * 40)..fillRange(0, 200, 255));
      await pick();
      expect(cubit.state.hasSubject, isTrue);
      expect(runner.requests.single.subjectMask, hasLength(20 * 40));
      runner.completers.last.complete(_pattern(1));
      await Future<void>.delayed(Duration.zero);
      cubit.setBackground(BackgroundMode.remove);
      cubit.setOutline(value: true);
      await Future<void>.delayed(Duration.zero);
      expect(runner.requests.last.background, BackgroundMode.remove);
      expect(runner.requests.last.outline, isTrue);
    });

    test('без маски объекта настройка фона не показывается', () async {
      masks.result = withFace();
      await pick();
      expect(cubit.state.hasSubject, isFalse);
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

  group('кисть «важное» (T60)', () {
    setUp(() => cubit = build(debounce: Duration.zero));
    tearDown(() => cubit.close());

    Future<void> pick() async {
      source.next = Success<List<PickedBookFile>>(<PickedBookFile>[photo()]);
      await cubit.pickPhotos();
      await Future<void>.delayed(Duration.zero);
    }

    test('мазок поднимает вес в запросе; ластик и очистка возвращают прежние', () async {
      masks.result = ImageMaskSet(width: 20, height: 40, subject: Uint8List(20 * 40)..fillRange(0, 200, 255));
      await pick();
      runner.completers.last.complete(_pattern(1));
      await Future<void>.delayed(Duration.zero);
      final Float32List before = runner.requests.last.importance!;
      expect(before[30 * 20 + 10], 0.5);

      cubit
        ..startBrush()
        ..addBrushStroke(<double>[0.5, 0.75, 0.5, 0.8]);
      expect(cubit.state.brush.strokes, hasLength(1));
      expect(cubit.state.canUndoBrush, isTrue);
      cubit.finishBrush();
      await Future<void>.delayed(Duration.zero);
      expect(runner.requests.last.importance![30 * 20 + 10], 4);
      expect(runner.requests.last.importance![0], before[0]);

      cubit
        ..startBrush()
        ..eraseBrush(<double>[0.5, 0.75])
        ..finishBrush();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.brush.isEmpty, isTrue);
      expect(runner.requests.last.importance![30 * 20 + 10], 0.5);
    });

    test('«Отмена» возвращает мазки, какими были; «Сбросить» убирает все', () async {
      await pick();
      cubit
        ..startBrush()
        ..addBrushStroke(<double>[0.5, 0.5])
        ..finishBrush()
        ..startBrush()
        ..addBrushStroke(<double>[0.2, 0.2])
        ..cancelBrush();
      expect(cubit.state.brush.strokes, hasLength(1));
      expect(cubit.state.brushing, isFalse);
      cubit.resetBrush();
      expect(cubit.state.brush.isEmpty, isTrue);
    });

    test('без масок мазок даёт вес 1 вокруг и 4 под собой; «Отменить» и очистка', () async {
      await pick();
      expect(runner.requests.last.importance, isNull);
      cubit
        ..startBrush()
        ..addBrushStroke(<double>[0.5, 0.5])
        ..addBrushStroke(<double>[0.1, 0.1]);
      cubit.undoBrush();
      expect(cubit.state.brush.strokes, hasLength(1));
      cubit.clearBrush();
      expect(cubit.state.brush.isEmpty, isTrue);
      cubit
        ..addBrushStroke(<double>[0.5, 0.5])
        ..finishBrush();
      await Future<void>.delayed(Duration.zero);
      final Float32List w = runner.requests.last.importance!;
      expect(w[0], 1);
      expect(w[20 * 20 + 10], 4);
    });

    test('мазок переживает поворот: остаётся на тех же клетках картинки', () async {
      await pick();
      cubit
        ..startBrush()
        ..addBrushStroke(<double>[0.02, 0.01])
        ..finishBrush();
      await cubit.rotate();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.brush.strokes, hasLength(1));
      final Float32List w = runner.requests.last.importance!;
      expect(w.any((v) => v == 4), isTrue);
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
    test('быстрые правки подряд: черновик сразу и один полный расчёт после паузы', () {
      fakeAsync((async) {
        cubit = build();
        source.next = Success<List<PickedBookFile>>(<PickedBookFile>[photo()]);
        unawaited(cubit.pickPhotos());
        async.flushMicrotasks();
        expect(runner.requests, hasLength(1)); // первый расчёт после выбора — сразу и полный
        expect(runner.requests.single.draft, isFalse);
        runner.completers.last.complete(_pattern(1));
        async.flushMicrotasks();

        cubit
          ..setColumns(50)
          ..setColumns(60)
          ..setColumns(70);
        async.flushMicrotasks();
        // Пока черновик считается, следующие правки не копятся в очереди.
        expect(runner.requests, hasLength(2));
        expect(runner.requests.last.draft, isTrue);
        expect(runner.requests.last.columns, 50);
        async.elapse(const Duration(milliseconds: 200));
        expect(runner.requests, hasLength(2));
        expect(cubit.state.calculating, isTrue);
        // Черновик устарел (параметры сменились): его не показываем, а считаем свежий.
        runner.completers.last.complete(_pattern(2));
        async.flushMicrotasks();
        expect(runner.requests, hasLength(3));
        expect(runner.requests.last.draft, isTrue);
        expect(runner.requests.last.columns, 70);
        async.elapse(const Duration(milliseconds: 200));
        expect(runner.requests, hasLength(4));
        expect(runner.requests.last.draft, isFalse);
        expect(runner.requests.last.columns, 70);
        unawaited(cubit.close());
      });
    });

    test('черновик показывается, но сохранить можно только полную схему', () async {
      cubit = build(debounce: const Duration(milliseconds: 20));
      addTearDown(cubit.close);
      await openPhoto();
      expect(cubit.state.canSave, isTrue);

      cubit.setColumns(50);
      await Future<void>.delayed(Duration.zero);
      expect(runner.requests.last.draft, isTrue);
      runner.completers.last.complete(_pattern(2));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.preview!.palette.single.rgb, const Rgb(2, 0, 0));
      expect(cubit.state.calculating, isTrue);
      expect(cubit.state.canSave, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(runner.requests.last.draft, isFalse);
      runner.completers.last.complete(_pattern(3));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.preview!.palette.single.rgb, const Rgb(3, 0, 0));
      expect(cubit.state.canSave, isTrue);
    });

    test('опоздавший черновик не затирает уже показанную полную схему', () async {
      cubit = build(debounce: const Duration(milliseconds: 20));
      addTearDown(cubit.close);
      await openPhoto();

      cubit.setColumns(50);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(runner.requests.map((r) => r.draft), <bool>[false, true, false]);
      runner.completers[2].complete(_pattern(3));
      await Future<void>.delayed(Duration.zero);
      runner.completers[1].complete(_pattern(2));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.preview!.palette.single.rgb, const Rgb(3, 0, 0));
      expect(cubit.state.canSave, isTrue);
    });

    test('плавные переходы — тоже пиксельный путь: черновик запрашивается', () async {
      cubit = build(debounce: const Duration(milliseconds: 20));
      addTearDown(cubit.close);
      await openPhoto();
      cubit.setDither(value: true);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(runner.requests.map((r) => r.draft), <bool>[false, true, false]);
    });

    test('закрытие мастера освобождает расчётную сессию', () async {
      cubit = build();
      await openPhoto();
      await cubit.close();
      expect(runner.releases, 1);
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
      // Плавные переходы на пиксельном пути — шаг упорядоченного дизеринга, а не Флойд — Стейнберг.
      expect(request.dither, isFalse);
      expect(request.steps.last, isA<OrderedDitherStep>());
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

  group('начальное ремесло', () {
    test('из вкладки «Вышивка» мастер открывается с вышивкой', () async {
      cubit = build(debounce: Duration.zero);
      addTearDown(cubit.close);
      await cubit.start(craft: Craft.crossStitch);
      expect(cubit.state.settings.craft, Craft.crossStitch);
      expect(cubit.state.settings.technique, Technique.crossStitch);
    });

    test('по умолчанию — бисер', () async {
      cubit = build(debounce: Duration.zero);
      addTearDown(cubit.close);
      await cubit.start();
      expect(cubit.state.settings.craft, Craft.beading);
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

  group('серия и отделки (T62)', () {
    setUp(() async {
      catalog = FakeCatalogRepository(<CatalogColor>[
        catalogColor('DB0010', 'Красный', '#C80A14', finish: 'opaque'),
        catalogColor('DB0011', 'Блестящий', '#C8C80A', finish: 'luster'),
        catalogColor('T-1', 'Toho', '#00FF00', brand: 'Toho', series: 'Round', finish: 'matte'),
      ]);
      cubit = build(debounce: Duration.zero);
      await cubit.start();
    });
    tearDown(() => cubit.close());

    test('по умолчанию Delica, матовый и блестящий', () {
      expect(cubit.beadSeries, BeadSeries.delica);
      expect(cubit.state.settings.finishGroups, <BeadFinishGroup>{BeadFinishGroup.solid, BeadFinishGroup.luster});
      expect(cubit.state.catalogColors, 2);
    });

    test('смена серии и группы отделок пересчитывает число цветов каталога', () {
      cubit.setBeadSeries(BeadSeries.round);
      expect(cubit.state.catalogColors, 1);
      cubit
        ..setBeadSeries(BeadSeries.delica)
        ..setFinishGroup(BeadFinishGroup.luster, value: false);
      expect(cubit.state.catalogColors, 1);
    });

    test('последнюю группу отделок выключить нельзя', () {
      cubit
        ..setFinishGroup(BeadFinishGroup.luster, value: false)
        ..setFinishGroup(BeadFinishGroup.solid, value: false);
      expect(cubit.state.settings.finishGroups, <BeadFinishGroup>{BeadFinishGroup.solid});
    });

    test('цветов в каталоге меньше, чем в схеме: мастер предупреждает', () {
      expect(cubit.state.catalogShort, isTrue); // 2 цвета при 8 в схеме
      cubit.setMaxColors(2);
      expect(cubit.state.catalogShort, isFalse); // 2 цвета при 2 в схеме
      cubit.setPaletteSource(PaletteSource.free);
      cubit.setMaxColors(8);
      expect(cubit.state.catalogShort, isFalse);
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

  group('вышивка (T46)', () {
    setUp(() {
      catalog = FakeCatalogRepository(<CatalogColor>[
        catalogColor('DB0010', 'Красный', '#C80A14'),
        catalogColor('321', 'Красный', '#C80A14', brand: 'DMC', series: '', material: CatalogMaterial.floss),
        catalogColor('797', 'Синий', '#0A14C8', brand: 'DMC', series: '', material: CatalogMaterial.floss),
      ]);
      cubit = build(debounce: Duration.zero);
    });
    tearDown(() => cubit.close());

    test('переход на вышивку ставит большие ширину и число цветов, канву и контуры', () {
      cubit.setCraft(Craft.crossStitch);
      final ImageToGridSettings s = cubit.state.settings;
      expect(s.technique, Technique.crossStitch);
      expect(s.columns, ImageToGridSettings.defaultStitchColumns);
      expect(s.maxColors, ImageToGridSettings.defaultStitchColors);
      expect(s.backstitch, isTrue);
      cubit.setCraft(Craft.beading);
      expect(cubit.state.settings.technique, Technique.loom);
      expect(cubit.state.settings.columns, ImageToGridSettings.defaultColumns);
    });

    test('при смене канвы ширина работы в сантиметрах сохраняется, число клеток пересчитывается', () {
      cubit.setCraft(Craft.crossStitch);
      cubit.setWidthCm(25);
      expect(cubit.state.settings.columns, 138);
      final Fabric aida18 = Fabric.create(kind: FabricKind.aida, count: 18).valueOrNull!;
      cubit.setFabric(aida18);
      expect(cubit.state.settings.columns, 177);
      expect(cubit.state.settings.widthCm, closeTo(25, 0.2));
    });

    test('каталог — мулине бренда по умолчанию, а запрос уходит с канвой и контурами', () async {
      await settings.write(SettingKeys.defaultFlossBrand, 'DMC');
      await cubit.start();
      cubit.setCraft(Craft.crossStitch);
      expect(cubit.state.catalogColors, 2);
      await openPhoto();
      final ImageToGridRequest request = runner.requests.last;
      expect(request.constraint.candidates, hasLength(2));
      expect(request.metrics, Fabric.standard);
      expect(request.backstitch, isTrue);
    });

    test('цвет канвы и бленды попадают в настройки', () {
      cubit.setCraft(Craft.crossStitch);
      cubit.setFabricColor(const Rgb(20, 20, 20));
      cubit.setBlends(value: true);
      cubit.setBackstitch(value: false);
      final ImageToGridSettings s = cubit.state.settings;
      expect(s.fabric.color, const Rgb(20, 20, 20));
      expect(s.blends, isTrue);
      expect(s.backstitch, isFalse);
    });

    test('сохранение: проект-вышивка с канвой как размером клетки', () async {
      await openPhoto();
      cubit.setCraft(Craft.crossStitch);
      runner.completers.last.complete(_pattern(7));
      await Future<void>.delayed(Duration.zero);
      cubit.setName('Котик');
      await cubit.save();
      final Project project = projects.projects[cubit.state.projectId!]!;
      expect(project.craft, Craft.crossStitch);
      expect(patterns.byProject[project.id]!.metrics, Fabric.standard);
      expect(patterns.byProject[project.id]!.layers, isNotNull);
    });
  });

  group('подсказка размера (T61)', () {
    late _AutoRunner auto;

    Future<void> settle() async {
      for (int i = 0; i < 40; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    Future<void> openAuto() async {
      source.next = Success<List<PickedBookFile>>(<PickedBookFile>[photo()]);
      await cubit.pickPhotos();
      await settle();
    }

    setUp(() {
      auto = _AutoRunner();
      runner = _ControlledRunner();
      cubit = ImageWizardCubit(
        source: source,
        processor: processor,
        decoder: decoder,
        runner: auto,
        masks: masks,
        catalog: catalog,
        settings: settings,
        createPattern: CreatePatternFromImage(
          CreateGridPattern(
            createProject: CreateProject(
              repository: projects,
              ids: FakeIdGenerator(),
              clock: FakeClock(DateTime.utc(2026)),
            ),
            projects: projects,
            patterns: patterns,
            ids: FakeIdGenerator(),
          ),
        ),
        debounce: Duration.zero,
        sizeHints: true,
      );
    });
    tearDown(() => cubit.close());

    test('после полного расчёта считается по пробам: узкая ширина, где корреляция дошла до порога', () async {
      await openAuto();
      expect(cubit.state.sizeHint, const SizeSuggestion(columns: 60, colors: 10, reached: true));
      final Iterable<ImageToGridRequest> probes = auto.requests.where((r) => r.measure);
      expect(probes.every((r) => r.draft), isTrue);
      expect(probes.map((r) => r.columns), <int>[30, 40, 60, 80, 100, 120]);
    });

    test(
      'размер по умолчанию берётся из подсказки, пока его никто не менял; ручная правка подсказку не перебивает',
      () async {
        await openAuto();
        expect(cubit.state.settings.columns, 60);
        expect(cubit.state.settings.maxColors, 10);
      },
    );

    test('если размер менялся вручную до прихода подсказки, она ничего не применяет сама', () async {
      source.next = Success<List<PickedBookFile>>(<PickedBookFile>[photo()]);
      await cubit.pickPhotos();
      await Future<void>.delayed(Duration.zero);
      cubit.setColumns(50);
      await settle();
      expect(cubit.state.sizeHint, isNotNull);
      expect(cubit.state.settings.columns, 50);
    });

    test('«как на фото» — предустановка снимается, возврат — предустановка на месте', () async {
      await openAuto();
      cubit.setPreset(null);
      expect(cubit.state.settings.preset, isNull);
      cubit.setPreset(GenerationPreset.balanced);
      expect(cubit.state.settings.preset, GenerationPreset.balanced);
    });

    test('первый предпросмотр приходит раньше подсказки', () async {
      source.next = Success<List<PickedBookFile>>(<PickedBookFile>[photo()]);
      await cubit.pickPhotos();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(auto.requests.first.measure, isFalse);
      expect(cubit.state.preview, isNotNull);
    });

    test('подсказка применяется одним касанием и помечается применённой', () async {
      await openAuto();
      cubit.applySizeHint();
      expect(cubit.state.settings.columns, 60);
      expect(cubit.state.settings.maxColors, 10);
      expect(cubit.state.sizeHintApplied, isTrue);
    });

    test('с лицом на бисере подсказка не уже 80 столбцов', () async {
      masks.result = ImageMaskSet(
        width: 20,
        height: 40,
        faces: const <DetectedFace>[
          DetectedFace(bounds: NormalizedRect(left: 0.25, top: 0.25, right: 0.75, bottom: 0.5)),
        ],
      );
      await openAuto();
      expect(cubit.state.sizeHint?.columns, 80);
    });

    test('смена кадра и ремесла делает подсказку устаревшей, потом считается заново', () async {
      await openAuto();
      expect(cubit.state.sizeHint, isNotNull);
      final Future<void> crop = cubit.setCrop(const CropRect(left: 0, top: 0, right: 0.5, bottom: 1));
      expect(cubit.state.sizeHint, isNull);
      await crop;
      await settle();
      expect(cubit.state.sizeHint, isNotNull);

      cubit.setCraft(Craft.crossStitch);
      expect(cubit.state.sizeHint, isNull);
      await settle();
      expect(cubit.state.sizeHint?.columns, 110);
      expect(cubit.state.sizeHint?.colors, 30);
    });

    test('новая фотография сбрасывает подсказку', () async {
      await openAuto();
      source.next = Success<List<PickedBookFile>>(<PickedBookFile>[photo('Кот.jpg')]);
      await cubit.pickPhotos();
      // Новая картинка принята, расчёт её схемы ещё идёт: старая подсказка не должна остаться.
      expect(cubit.state.sizeHint, isNull);
    });

    test('у фото без разброса светлоты подсказки нет', () async {
      auto.correlation = (columns) => null;
      await openAuto();
      expect(cubit.state.sizeHint, isNull);
    });

    test('размер по назначению: бисер — столбцы, вышивка — сантиметры через канву', () async {
      await openAuto();
      cubit.setPurpose(SizePurpose.large);
      expect(cubit.state.settings.columns, 100);
      cubit.setCraft(Craft.crossStitch);
      cubit.setPurpose(SizePurpose.medium);
      expect(cubit.state.settings.columns, Fabric.standard.cellsForCm(25));
      expect(cubit.state.settings.widthCm, closeTo(25, 0.3));
    });

    Future<void> widenWith(double faceWidth) async {
      masks.result = ImageMaskSet(
        width: 20,
        height: 40,
        faces: <DetectedFace>[
          DetectedFace(bounds: NormalizedRect(left: 0.1, top: 0.1, right: 0.1 + faceWidth, bottom: 0.5)),
        ],
      );
      await openAuto();
      cubit.setColumns(30);
      await settle();
      cubit.widenForFace();
    }

    test('«Схема шире» берёт ширину подсказки (80), если она не уже нужной лицу', () async {
      await widenWith(0.3); // лицу нужно 67 столбцов
      expect(cubit.state.settings.columns, 80);
      expect(cubit.state.settings.maxColors, cubit.state.sizeHint!.colors);
    });

    test('«Схема шире» берёт ширину лица, если подсказка уже неё', () async {
      await widenWith(0.2); // лицу нужно 100 столбцов, подсказка 80
      expect(cubit.state.settings.columns, 100);
    });

    test('бисера на лицо не хватает: на узкой схеме с лицом предупреждение, на широкой нет', () async {
      masks.result = ImageMaskSet(
        width: 20,
        height: 40,
        faces: const <DetectedFace>[
          DetectedFace(bounds: NormalizedRect(left: 0.25, top: 0.25, right: 0.75, bottom: 0.5)),
        ],
      );
      await openAuto();
      cubit.setColumns(40);
      expect(cubit.state.beadsTooSmallForFace, isTrue);
      cubit.setColumns(80);
      expect(cubit.state.beadsTooSmallForFace, isFalse);
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

  test('вид предпросмотра переключается между схемой и «как будет»', () async {
    cubit = build(debounce: Duration.zero);
    addTearDown(cubit.close);
    await openPhoto();
    expect(cubit.state.realistic, isFalse);
    cubit.setRealistic(value: true);
    expect(cubit.state.realistic, isTrue);
    cubit.setRealistic(value: false);
    expect(cubit.state.realistic, isFalse);
  });
}
