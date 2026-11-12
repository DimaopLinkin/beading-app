import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/bead_finish_group.dart';
import 'package:beading/domain/catalog/bead_series.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_decoder.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_runner.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/use_cases/create_pattern_from_image.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_cubit.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_screen.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_image_masks.dart';
import '../../support/fake_image_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/test_images.dart';

class _InstantRunner implements ImageToGridRunner {
  @override
  Future<GeneratedPattern> run(ImageToGridRequest request) async => GeneratedPattern(
    grid: Grid.fromCells(width: 3, height: 2, cells: const <int>[1, 2, 1, 2, 1, 2]),
    palette: const <PaletteEntry>[
      PaletteEntry(rgb: Rgb(200, 10, 10)),
      PaletteEntry(rgb: Rgb(10, 10, 200)),
    ],
  );

  @override
  Future<void> release() async {}
}

class _Decoder implements ImageDecoder {
  @override
  Future<Result<SourceImage>> decode(Uint8List bytes, {int maxSide = 1024}) async =>
      Success<SourceImage>(SourceImage.solid(width: 10, height: 10, r: 1, g: 2, b: 3));
}

void main() {
  late FakeBookImageSource source;
  late FakeProjectRepository projects;
  late FakeImageMasks masks;
  late ImageWizardCubit cubit;

  setUp(() {
    source = FakeBookImageSource();
    masks = FakeImageMasks();
    projects = FakeProjectRepository();
    final FakeIdGenerator ids = FakeIdGenerator();
    cubit = ImageWizardCubit(
      source: source,
      processor: FakeImageProcessor(),
      decoder: _Decoder(),
      runner: _InstantRunner(),
      masks: masks,
      catalog: FakeCatalogRepository(<CatalogColor>[]),
      settings: FakeSettingsRepository(),
      createPattern: CreatePatternFromImage(
        CreateGridPattern(
          createProject: CreateProject(repository: projects, ids: ids, clock: FakeClock(DateTime.utc(2026))),
          projects: projects,
          patterns: FakeGridPatternRepository(),
          ids: ids,
        ),
      ),
      debounce: Duration.zero,
    );
    addTearDown(cubit.close);
  });

  Widget wrap(CupertinoThemeData theme, {bool camera = true}) => CupertinoApp(
    theme: theme,
    builder: AppTheme.builder,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<ImageWizardCubit>.value(
      value: cubit,
      child: ImageWizardScreen(cameraAvailable: camera),
    ),
  );

  Future<void> openPhoto(WidgetTester tester, CupertinoThemeData theme) async {
    source.next = Success<List<PickedBookFile>>(<PickedBookFile>[
      PickedBookFile(name: 'Розы.jpg', bytes: Uint8List.fromList(<int>[1, 2])),
    ]);
    await tester.pumpWidget(wrap(theme));
    await tester.tap(find.text('Выбрать из Фото'));
    await tester.pumpAndSettle();
  }

  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('выбор источника в теме ${theme.brightness}', (tester) async {
      await tester.pumpWidget(wrap(theme));
      expect(find.text('Сделать снимок'), findsOneWidget);
      expect(find.text('Выбрать из Фото'), findsOneWidget);
      expect(find.text('Выбрать из Файлов'), findsOneWidget);
    });

    testWidgets('правка в теме ${theme.brightness}: предпросмотр, параметры и сохранение', (tester) async {
      // Высокий экран: настройки стали длиннее, а нижняя кнопка закрывает край списка.
      tester.view
        ..physicalSize = const Size(800, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openPhoto(tester, theme);
      expect(find.byKey(const ValueKey<String>('wizard-grid')), findsOneWidget);
      expect(find.text('3 × 2 бусин'), findsOneWidget);
      expect(find.text('Станок', skipOffstage: false), findsOneWidget);
      expect(find.text('Delica 11/0', skipOffstage: false), findsOneWidget);
      expect(tester.widget<CupertinoButton>(find.byKey(const ValueKey<String>('wizard-save'))).onPressed, isNotNull);

      final Finder technique = find.byKey(const ValueKey<String>('wizard-technique'));
      await tester.ensureVisible(technique);
      await tester.pumpAndSettle();
      await tester.tap(technique);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Мозаика'));
      await tester.pumpAndSettle();
      expect(cubit.state.settings.technique.name, 'peyote');
    });
  }

  testWidgets('переключатель «Выделять главное» виден, только когда на фото нашлись лица или объект', (tester) async {
    await openPhoto(tester, AppTheme.light);
    expect(find.text('Выделять главное', skipOffstage: false), findsNothing);
  });

  testWidgets('нашлось лицо — переключатель выделения главного меняет настройку', (tester) async {
    masks.result = ImageMaskSet(
      width: 10,
      height: 10,
      faces: const <DetectedFace>[
        DetectedFace(bounds: NormalizedRect(left: 0.2, top: 0.2, right: 0.6, bottom: 0.6)),
      ],
    );
    await openPhoto(tester, AppTheme.light);
    final Finder toggle = find.byKey(const ValueKey<String>('wizard-use-masks'));
    await tester.scrollUntilVisible(toggle, 200, scrollable: find.byType(Scrollable).last);
    expect(cubit.state.settings.useMasks, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(cubit.state.settings.useMasks, isFalse);
  });

  for (final Brightness b in Brightness.values) {
    testWidgets('кисть «важное» в теме $b: мазок, «Готово», бейдж и сброс', (tester) async {
      await openPhoto(tester, b == Brightness.dark ? AppTheme.dark : AppTheme.light);
      final Finder row = find.byKey(const ValueKey<String>('wizard-brush'));
      await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).last);
      await tester.tap(row);
      await tester.pump();
      expect(cubit.state.brushing, isTrue);

      final Offset canvas = tester.getCenter(find.byKey(const ValueKey<String>('brush-canvas')));
      final TestGesture finger = await tester.startGesture(canvas);
      await finger.moveBy(const Offset(20, 5));
      await finger.up();
      await tester.pump();
      expect(cubit.state.brush.strokes, hasLength(1));

      await tester.tap(find.byKey(const ValueKey<String>('brush-done')));
      await tester.pumpAndSettle();
      expect(cubit.state.brushing, isFalse);
      await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).last);
      expect(find.text('Выделено вручную'), findsOneWidget);
      final Finder hint = find.byKey(const ValueKey<String>('wizard-brush-crop-hint'));
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(hint, findsOneWidget);

      final Finder reset = find.byKey(const ValueKey<String>('wizard-brush-reset'));
      await tester.scrollUntilVisible(reset, 200, scrollable: find.byType(Scrollable).last);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(cubit.state.brush.isEmpty, isTrue);
      expect(hint, findsNothing);
    });
  }

  testWidgets('кисть: мышь без нажатия показывает кружок, уход мыши убирает', (tester) async {
    await openPhoto(tester, AppTheme.light);
    final Finder row = find.byKey(const ValueKey<String>('wizard-brush'));
    await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(row);
    await tester.pump();
    final Finder canvas = find.byKey(const ValueKey<String>('brush-canvas'));
    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(canvas));
    await tester.pump();
    expect(cubit.state.brush.isEmpty, isTrue);
    final CustomPaint paint = tester.widget<CustomPaint>(
      find.descendant(of: canvas, matching: find.byType(CustomPaint)).first,
    );
    final dynamic painter = paint.painter;
    // Painter приватный, кружок читаем через его поле.
    // ignore: avoid_dynamic_calls
    expect((painter.cursor as ValueNotifier<Offset?>).value, isNotNull);
    await mouse.moveTo(const Offset(1, 1));
    await tester.pump();
    // Painter приватный, кружок читаем через его поле.
    // ignore: avoid_dynamic_calls
    expect((painter.cursor as ValueNotifier<Offset?>).value, isNull);
  });

  testWidgets('кисть: на широком экране панель слева, при крупном шрифте размеры уходят в меню', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openPhoto(tester, AppTheme.light);
    final Finder brushRow = find.byKey(const ValueKey<String>('wizard-brush'));
    await tester.scrollUntilVisible(brushRow, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(brushRow);
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('brush-size-0')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<String>('brush-draw'))).dx,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey<String>('brush-canvas'))).dx),
    );
    // Кружок кисти под пальцем не мешает рисованию.
    final TestGesture finger = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey<String>('brush-canvas'))),
    );
    await finger.moveBy(const Offset(15, 5));
    await tester.pump();
    await finger.up();
    await tester.pump();
    expect(cubit.state.brush.strokes, hasLength(1));
  });

  testWidgets('кисть при крупном шрифте: размер в меню, кнопки не меньше 84 pt', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openPhoto(tester, AppTheme.light);
    final Finder brushRow = find.byKey(const ValueKey<String>('wizard-brush'));
    await tester.scrollUntilVisible(brushRow, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(brushRow);
    await tester.pump();
    // Крупный шрифт включаем уже в режиме кисти: перед ним мастер тесен и на 2× (свои переполнения).
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('brush-size-0')), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey<String>('brush-draw'))).height, greaterThanOrEqualTo(84));
    await tester.tap(find.byKey(const ValueKey<String>('brush-size-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Крупный'));
    await tester.pumpAndSettle();
    expect(cubit.state.brushSize, 2);
  });

  ImageMaskSet faceOfWidth(double width) => ImageMaskSet(
    width: 10,
    height: 10,
    faces: <DetectedFace>[
      DetectedFace(
        bounds: NormalizedRect(left: 0.3, top: 0.2, right: 0.3 + width, bottom: 0.2 + width),
      ),
    ],
  );

  testWidgets('мелкое лицо: плашка с двумя действиями, обрезка и ширина меняют настройки', (tester) async {
    masks.result = faceOfWidth(0.2);
    await openPhoto(tester, AppTheme.light);
    final Finder warning = find.byKey(const ValueKey<String>('wizard-face-warning'));
    await tester.scrollUntilVisible(warning, 200, scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('Лицо шириной всего'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey<String>('wizard-face-wider')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('wizard-face-wider')));
    await tester.pumpAndSettle();
    expect(cubit.state.settings.columns, 100);
    expect(find.byKey(const ValueKey<String>('wizard-face-warning'), skipOffstage: false), findsNothing);
  });

  testWidgets('мелкое лицо: «Обрезать по лицу» сужает рамку', (tester) async {
    masks.result = faceOfWidth(0.2);
    await openPhoto(tester, AppTheme.light);
    final Finder warning = find.byKey(const ValueKey<String>('wizard-face-warning'));
    await tester.scrollUntilVisible(warning, 200, scrollable: find.byType(Scrollable).last);

    await tester.ensureVisible(find.byKey(const ValueKey<String>('wizard-face-crop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('wizard-face-crop')));
    await tester.pumpAndSettle();
    expect(cubit.state.crop.isFull, isFalse);
    expect(cubit.state.crop.width, lessThan(1));
  });

  testWidgets('крупное лицо или выключенное «Выделять главное»: плашки нет', (tester) async {
    masks.result = faceOfWidth(0.6);
    await openPhoto(tester, AppTheme.light);
    expect(find.byKey(const ValueKey<String>('wizard-face-warning'), skipOffstage: false), findsNothing);

    masks.result = faceOfWidth(0.2);
    await cubit.setCrop(CropRect.full);
    await tester.pumpAndSettle();
    expect(cubit.state.faceAdvice, isNotNull);
    cubit.setUseMasks(value: false);
    await tester.pumpAndSettle();
    expect(cubit.state.faceAdvice, isNull);
    expect(find.byKey(const ValueKey<String>('wizard-face-warning'), skipOffstage: false), findsNothing);
  });

  testWidgets('нашёлся предмет — настройки «Фон» и «Обводка» видны и меняют настройки', (tester) async {
    masks.result = ImageMaskSet(width: 10, height: 10, subject: Uint8List(100)..fillRange(0, 50, 255));
    await openPhoto(tester, AppTheme.light);
    await tester.scrollUntilVisible(find.text('Убрать'), 200, scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('Убрать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Убрать'));
    await tester.pumpAndSettle();
    final Finder outline = find.byKey(const ValueKey<String>('wizard-outline'));
    await tester.scrollUntilVisible(outline, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(outline);
    await tester.pumpAndSettle();
    expect(cubit.state.settings.outline, isTrue);
    expect(cubit.state.settings.background.name, 'remove');
  });

  testWidgets('палитра из каталога: серия и отделки видны, переключатели меняют настройки (T62)', (tester) async {
    await openPhoto(tester, AppTheme.light);
    final Finder series = find.byKey(const ValueKey<String>('wizard-bead-series'));
    await tester.scrollUntilVisible(series, 200, scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('Круглый Toho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Круглый Toho'));
    await tester.pumpAndSettle();
    expect(cubit.state.settings.beadSeries, BeadSeries.round);
    final Finder transparent = find.byKey(const ValueKey<String>('wizard-finish-transparent'));
    await tester.ensureVisible(transparent);
    await tester.tap(transparent);
    await tester.pumpAndSettle();
    expect(cubit.state.settings.finishGroups, contains(BeadFinishGroup.transparent));
  });

  testWidgets('без предмета настроек фона нет', (tester) async {
    await openPhoto(tester, AppTheme.light);
    expect(find.byKey(const ValueKey<String>('wizard-outline'), skipOffstage: false), findsNothing);
  });

  group('вышивка (T46)', () {
    Future<void> toStitch(WidgetTester tester) async {
      await openPhoto(tester, AppTheme.light);
      final Finder craft = find.byKey(const ValueKey<String>('wizard-craft'));
      await tester.scrollUntilVisible(craft, 200, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Вышивка'));
      await tester.pumpAndSettle();
    }

    testWidgets('переключатель ремесла: канва и ширина в сантиметрах вместо бисера, контуры включены', (tester) async {
      await toStitch(tester);
      expect(cubit.state.settings.craft, Craft.crossStitch);
      expect(find.byKey(const ValueKey<String>('wizard-fabric'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('wizard-bead-size'), skipOffstage: false), findsNothing);
      expect(find.text('Аида 14', skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('wizard-width-cm'), skipOffstage: false), findsOneWidget);
      expect(find.text('Цвета мулине', skipOffstage: false), findsOneWidget);
      final Finder backstitch = find.byKey(const ValueKey<String>('wizard-backstitch'));
      await tester.scrollUntilVisible(backstitch, 200, scrollable: find.byType(Scrollable).last);
      expect(tester.widget<CupertinoSwitch>(backstitch).value, isTrue);
      await tester.tap(backstitch);
      await tester.pumpAndSettle();
      expect(cubit.state.settings.backstitch, isFalse);
    });

    testWidgets('размер схемы показан и в клетках, и в сантиметрах', (tester) async {
      await toStitch(tester);
      expect(find.text('3 × 2 крестиков, 0,5 × 0,4 см', skipOffstage: false), findsOneWidget);
    });

    testWidgets('выбор канвы и её цвета меняет настройки', (tester) async {
      await toStitch(tester);
      await tester.tap(find.byKey(const ValueKey<String>('wizard-fabric')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Аида 18'));
      await tester.pumpAndSettle();
      expect(cubit.state.settings.fabric.count, 18);
      expect(cubit.state.settings.fabric.kind, FabricKind.aida);

      await tester.tap(find.byKey(const ValueKey<String>('wizard-fabric-color')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Чёрная'));
      await tester.pumpAndSettle();
      expect(cubit.state.settings.fabric.color, const Rgb(20, 20, 20));
    });

    testWidgets('выбор производителя мулине меняет бренд мастера', (tester) async {
      await toStitch(tester);
      await tester.tap(find.byKey(const ValueKey<String>('wizard-floss-brand')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anchor'));
      await tester.pumpAndSettle();
      expect(cubit.state.flossBrand, 'Anchor');
    });

    testWidgets('обводка бусиной у вышивки не показывается', (tester) async {
      masks.result = ImageMaskSet(width: 10, height: 10, subject: Uint8List(100)..fillRange(0, 50, 255));
      await toStitch(tester);
      expect(find.byKey(const ValueKey<String>('wizard-outline'), skipOffstage: false), findsNothing);
      expect(find.byKey(const ValueKey<String>('wizard-background'), skipOffstage: false), findsOneWidget);
    });
  });

  testWidgets('на Mac кнопки камеры нет', (tester) async {
    await tester.pumpWidget(wrap(AppTheme.light, camera: false));
    expect(find.text('Сделать снимок'), findsNothing);
  });

  testWidgets('отказ в доступе показывает понятный текст', (tester) async {
    source.next = const Err<List<PickedBookFile>>(StorageFailure('denied'));
    await tester.pumpWidget(wrap(AppTheme.light));
    await tester.tap(find.text('Выбрать из Фото'));
    await tester.pump();
    expect(find.textContaining('Не удалось открыть выбранный источник'), findsOneWidget);
  });

  testWidgets('удержание предпросмотра показывает исходную картинку', (tester) async {
    final Uint8List png = (await tester.runAsync(redBluePng))!;
    source.next = Success<List<PickedBookFile>>(<PickedBookFile>[PickedBookFile(name: 'a.png', bytes: png)]);
    await tester.pumpWidget(wrap(AppTheme.light));
    await tester.tap(find.text('Выбрать из Фото'));
    await tester.pumpAndSettle();
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey<String>('wizard-preview'))),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(cubit.state.comparing, isTrue);
    await gesture.up();
    await tester.pump();
    expect(cubit.state.comparing, isFalse);
  });

  testWidgets('сохранение закрывает мастер с id проекта', (tester) async {
    await openPhoto(tester, AppTheme.light);
    await tester.tap(find.byKey(const ValueKey<String>('wizard-save')));
    await tester.pumpAndSettle();
    expect(cubit.state.projectId, isNotNull);
    expect(projects.projects, hasLength(1));
  });
}
