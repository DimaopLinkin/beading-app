import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/generation_stats.dart';
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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_image_masks.dart';
import '../../support/fake_image_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_settings_repository.dart';

/// Мгновенный запуск: пробы подсказки получают корреляцию, которая доходит до порога на 60 столбцах.
class _Runner implements ImageToGridRunner {
  @override
  Future<GeneratedPattern> run(ImageToGridRequest request) async => GeneratedPattern(
    grid: Grid.fromCells(width: 3, height: 2, cells: const <int>[1, 2, 1, 2, 1, 2]),
    palette: const <PaletteEntry>[
      PaletteEntry(rgb: Rgb(200, 10, 10)),
      PaletteEntry(rgb: Rgb(10, 10, 200)),
    ],
    stats: request.measure
        ? GenerationStats(
            singleCells: 0,
            colorCount: 2,
            meanDeltaE: 0,
            stageTimes: const <String, Duration>{},
            lightnessCorrelation: request.columns >= 60 ? 0.95 : 0.7,
          )
        : null,
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
  late FakeImageMasks masks;
  late ImageWizardCubit cubit;

  setUp(() {
    source = FakeBookImageSource();
    masks = FakeImageMasks();
    final FakeProjectRepository projects = FakeProjectRepository();
    final FakeIdGenerator ids = FakeIdGenerator();
    cubit = ImageWizardCubit(
      source: source,
      processor: FakeImageProcessor(),
      decoder: _Decoder(),
      runner: _Runner(),
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
      sizeHints: true,
    );
    addTearDown(cubit.close);
  });

  Future<void> open(WidgetTester tester, CupertinoThemeData theme) async {
    tester.view
      ..physicalSize = const Size(800, 2000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    source.next = Success<List<PickedBookFile>>(<PickedBookFile>[
      PickedBookFile(name: 'Розы.jpg', bytes: Uint8List.fromList(<int>[1, 2])),
    ]);
    await tester.pumpWidget(
      CupertinoApp(
        theme: theme,
        builder: AppTheme.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<ImageWizardCubit>.value(value: cubit, child: const ImageWizardScreen(cameraAvailable: true)),
      ),
    );
    await tester.tap(find.text('Выбрать из Фото'));
    await tester.pumpAndSettle();
  }

  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('бисер в теме ${theme.brightness}: размеры по назначению и подсказка применяется одним касанием', (
      tester,
    ) async {
      await open(tester, theme);
      final Finder hint = find.byKey(const ValueKey<String>('wizard-size-hint'));
      await tester.scrollUntilVisible(hint, 200, scrollable: find.byType(Scrollable).last);
      expect(find.textContaining('от 60 бусин по ширине и 10 цветов'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('wizard-size-hint-apply')));
      await tester.pumpAndSettle();
      expect(cubit.state.settings.columns, 60);
      expect(find.byKey(const ValueKey<String>('wizard-size-hint-applied'), skipOffstage: false), findsOneWidget);

      await tester.tap(find.text('Картина'));
      await tester.pumpAndSettle();
      expect(cubit.state.settings.columns, 100);
      expect(find.byKey(const ValueKey<String>('wizard-size-hint-apply'), skipOffstage: false), findsOneWidget);
    });
  }

  testWidgets('вышивка: размеры в сантиметрах, подсказка в сантиметрах на канве', (tester) async {
    await open(tester, AppTheme.light);
    cubit.setCraft(Craft.crossStitch);
    await tester.pumpAndSettle();
    final Finder hint = find.byKey(const ValueKey<String>('wizard-size-hint'));
    await tester.scrollUntilVisible(hint, 200, scrollable: find.byType(Scrollable).last);
    // 110 крестиков на аиде 14: 110 × 25,4 / 14 = 199,6 мм.
    expect(find.textContaining('на канве Аида 14 лучше от 20,0 см (110 крестиков) и 30 цветов'), findsOneWidget);
    await tester.tap(find.text('25,0 см'));
    await tester.pumpAndSettle();
    expect(cubit.state.settings.widthCm, closeTo(25, 0.3));
  });

  testWidgets('лицо на узкой схеме из бисера: честное предупреждение и переход на вышивку', (tester) async {
    masks.result = ImageMaskSet(
      width: 10,
      height: 10,
      faces: const <DetectedFace>[
        DetectedFace(bounds: NormalizedRect(left: 0.3, top: 0.2, right: 0.8, bottom: 0.7)),
      ],
    );
    await open(tester, AppTheme.light);
    final Finder warning = find.byKey(const ValueKey<String>('wizard-beads-few'));
    await tester.scrollUntilVisible(warning, 200, scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('Бисера на такое лицо не хватает'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('wizard-beads-to-stitch')));
    await tester.pumpAndSettle();
    expect(cubit.state.settings.craft, Craft.crossStitch);
    expect(find.byKey(const ValueKey<String>('wizard-beads-few'), skipOffstage: false), findsNothing);
  });
}
