import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_decoder.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_runner.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/use_cases/create_pattern_from_image.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_cubit.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_screen.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
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
}

class _Decoder implements ImageDecoder {
  @override
  Future<Result<SourceImage>> decode(Uint8List bytes, {int maxSide = 1024}) async =>
      Success<SourceImage>(SourceImage.solid(width: 10, height: 10, r: 1, g: 2, b: 3));
}

void main() {
  late FakeBookImageSource source;
  late FakeProjectRepository projects;
  late ImageWizardCubit cubit;

  setUp(() {
    source = FakeBookImageSource();
    projects = FakeProjectRepository();
    final FakeIdGenerator ids = FakeIdGenerator();
    cubit = ImageWizardCubit(
      source: source,
      processor: FakeImageProcessor(),
      decoder: _Decoder(),
      runner: _InstantRunner(),
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
      await openPhoto(tester, theme);
      expect(find.byKey(const ValueKey<String>('wizard-grid')), findsOneWidget);
      expect(find.text('3 × 2 бусин'), findsOneWidget);
      expect(find.text('Станок'), findsOneWidget);
      expect(find.text('Delica 11/0', skipOffstage: false), findsOneWidget);
      expect(tester.widget<CupertinoButton>(find.byKey(const ValueKey<String>('wizard-save'))).onPressed, isNotNull);

      await tester.tap(find.text('Мозаика'));
      await tester.pumpAndSettle();
      expect(cubit.state.settings.technique.name, 'peyote');
    });
  }

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
