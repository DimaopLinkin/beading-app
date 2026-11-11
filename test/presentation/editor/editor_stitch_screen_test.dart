import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/use_cases/save_grid_pattern.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/presentation/editor/editor_canvas.dart';
import 'package:beading/presentation/editor/editor_cubit.dart';
import 'package:beading/presentation/editor/editor_screen.dart';
import 'package:beading/presentation/editor/editor_state.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_settings_repository.dart';

/// Нитки двух производителей: фильтры по материалу и бренду работают, как у настоящего каталога.
class _FlossCatalog implements CatalogRepository {
  static const CatalogColor gammaRed = CatalogColor(
    material: CatalogMaterial.floss,
    brand: 'Гамма',
    series: 'Мулине',
    code: '3071',
    name: 'Красный',
    rgb: Rgb(200, 0, 0),
  );
  static const CatalogColor gammaBlue = CatalogColor(
    material: CatalogMaterial.floss,
    brand: 'Гамма',
    series: 'Мулине',
    code: '3095',
    name: 'Синий',
    rgb: Rgb(0, 0, 200),
  );
  static const CatalogColor dmcBlack = CatalogColor(
    material: CatalogMaterial.floss,
    brand: 'DMC',
    series: 'Мулине',
    code: '310',
    name: 'Чёрный',
    rgb: Rgb(0, 0, 0),
  );
  static const CatalogColor miyukiRed = CatalogColor(
    material: CatalogMaterial.bead,
    brand: 'Miyuki',
    series: 'Delica',
    code: 'DB0010',
    name: 'Красный матовый',
    rgb: Rgb(200, 10, 20),
    sizeCode: '11/0',
  );
  static const List<CatalogColor> all = <CatalogColor>[gammaRed, gammaBlue, dmcBlack, miyukiRed];

  final List<String?> searchedBrands = <String?>[];

  @override
  Future<Result<List<CatalogColor>>> search({String query = '', CatalogMaterial? material, String? brand}) async {
    searchedBrands.add(brand);
    return Success<List<CatalogColor>>(
      all.where((c) => (material == null || c.material == material) && (brand == null || c.brand == brand)).toList(),
    );
  }

  @override
  Future<Result<List<String>>> brands(CatalogMaterial material) async =>
      Success<List<String>>(material == CatalogMaterial.floss ? <String>['DMC', 'Гамма'] : <String>[]);

  @override
  Future<Result<CatalogColor?>> find(String brand, String code) async =>
      Success<CatalogColor?>(all.where((c) => c.brand == brand && c.code == code).firstOrNull);

  @override
  Future<Result<List<ColorMatch<CatalogColor>>>> nearest(
    Rgb target, {
    required CatalogMaterial material,
    String? brand,
    int count = 5,
  }) async => const Success<List<ColorMatch<CatalogColor>>>(<ColorMatch<CatalogColor>>[]);
}

void main() {
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;
  late EditorCubit cubit;
  late _FlossCatalog floss;

  Future<void> pumpEditor(WidgetTester tester, {bool stitch = true, Size size = const Size(390, 844)}) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    projects = FakeProjectRepository();
    patterns = FakeGridPatternRepository();
    floss = _FlossCatalog();
    projects.projects['p'] = Project(
      id: 'p',
      name: 'Котик',
      status: ProjectStatus.idea,
      craft: stitch ? Craft.crossStitch : Craft.beading,
      technique: Technique.defaultFor(stitch ? Craft.crossStitch : Craft.beading),
      contentKind: ContentKind.grid,
      notes: '',
      coverPath: null,
      lastWorkedAt: DateTime.utc(2026),
    );
    patterns.byProject['p'] = GridPattern(
      id: 'pat',
      projectId: 'p',
      geometry: stitch ? const RectangularGeometry() : const GridGeometry.rectangular(),
      metrics: stitch ? Fabric.standard : BeadSize.delica11,
      grid: Grid.empty(width: 8, height: 8),
      palette: stitch
          ? PaletteSnapshot(<PatternColor>[
              PatternColor(
                rgb: const Rgb(200, 0, 0),
                name: 'Красный',
                components: const <CatalogRef>[CatalogRef(brand: 'Гамма', code: '3071')],
              ),
            ])
          : samplePalette(),
    );
    cubit = EditorCubit(
      projectId: 'p',
      projects: projects,
      patterns: patterns,
      savePattern: SaveGridPattern(patterns),
      touchProject: TouchProject(repository: projects, clock: FakeClock(DateTime.utc(2026, 2))),
    );
    addTearDown(cubit.close);
    final FakeSettingsRepository settings = FakeSettingsRepository()
      ..values[SettingKeys.defaultFlossBrand.name] = 'Гамма';
    await tester.pumpWidget(
      CupertinoApp(
        theme: AppTheme.light,
        builder: AppTheme.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: BlocProvider<EditorCubit>.value(
          value: cubit,
          child: EditorScreen(catalog: stitch ? floss : FakeCatalogRepository(), settings: settings),
        ),
      ),
    );
    await cubit.load();
    await tester.pumpAndSettle();
  }

  Future<void> selectTool(WidgetTester tester, String name) async {
    final Finder finder = find.byKey(ValueKey<String>('tool-$name'));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    await cubit.close();
    await tester.pump();
  }

  testWidgets('у вышивки есть инструменты стежков, у бисера их нет', (tester) async {
    await pumpEditor(tester);
    for (final String name in <String>[
      'halfStitch',
      'quarterStitch',
      'threeQuarterStitch',
      'petit',
      'backstitch',
      'knot',
    ]) {
      expect(find.byKey(ValueKey<String>('tool-$name'), skipOffstage: false), findsOneWidget, reason: name);
    }
    await finish(tester);

    await pumpEditor(tester, stitch: false);
    expect(find.byKey(const ValueKey<String>('tool-backstitch'), skipOffstage: false), findsNothing);
    await finish(tester);
  });

  testWidgets('узелок ставится касанием полотна и виден в слоях', (tester) async {
    await pumpEditor(tester);
    await selectTool(tester, 'knot');

    await tester.tapAt(tester.getCenter(find.byType(EditorCanvas)));
    await tester.pump();

    expect(cubit.state.layers!.points, hasLength(1));
    await finish(tester);
  });

  testWidgets('протяжка бэкстича ставит линию, полукрестик — стежок в клетке', (tester) async {
    await pumpEditor(tester);
    await selectTool(tester, 'backstitch');
    final Offset center = tester.getCenter(find.byType(EditorCanvas));

    final TestGesture drag = await tester.startGesture(center);
    await drag.moveTo(center + const Offset(40, 0));
    await drag.up();
    await tester.pump();

    expect(cubit.state.layers!.lines, hasLength(1));

    await selectTool(tester, 'halfStitch');
    await tester.tapAt(center + const Offset(0, 60));
    await tester.pump();
    expect(cubit.state.layers!.partials, hasLength(1));
    await finish(tester);
  });

  testWidgets('первое касание бэкстича отмечает начало, подсказка меняется', (tester) async {
    await pumpEditor(tester);
    await selectTool(tester, 'backstitch');
    expect(find.textContaining('Коснитесь двух узлов подряд'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byType(EditorCanvas)));
    await tester.pump();

    expect(cubit.state.lineAnchor, isNotNull);
    expect(find.byKey(const ValueKey<String>('editor-line-anchor')), findsOneWidget);
    expect(find.textContaining('Начало отмечено'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('долгое нажатие на инструмент показывает его название', (tester) async {
    await pumpEditor(tester);
    final Finder knot = find.byKey(const ValueKey<String>('tool-knot'));
    await tester.ensureVisible(knot);

    final TestGesture press = await tester.startGesture(tester.getCenter(knot));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Французский узелок'), findsOneWidget);
    await press.up();
    await tester.pump();

    expect(find.text('Французский узелок'), findsNothing);
    await finish(tester);
  });

  testWidgets('новая нитка: каталог ниток с брендом из настроек', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byKey(const ValueKey<String>('palette-add')));
    await tester.pumpAndSettle();

    expect(floss.searchedBrands.last, 'Гамма');
    expect(find.byKey(ValueKey<String>('cat-${_FlossCatalog.gammaBlue.id}')), findsOneWidget);
    expect(find.byKey(ValueKey<String>('cat-${_FlossCatalog.dmcBlack.id}')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('brand-DMC')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey<String>('cat-${_FlossCatalog.dmcBlack.id}')), findsOneWidget);

    await tester.tap(find.byKey(ValueKey<String>('cat-${_FlossCatalog.dmcBlack.id}')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('color-done')));
    await tester.pumpAndSettle();

    expect(cubit.state.pattern!.palette.colorAt(2)!.components.single, const CatalogRef(brand: 'DMC', code: '310'));
    await finish(tester);
  });

  testWidgets('смесь двух ниток собирается из двух позиций каталога', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byKey(const ValueKey<String>('palette-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey<String>('cat-${_FlossCatalog.gammaRed.id}')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('color-blend')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey<String>('cat-${_FlossCatalog.gammaBlue.id}')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('color-done')));
    await tester.pumpAndSettle();

    final PatternColor blend = cubit.state.pattern!.palette.colorAt(2)!;
    expect(blend.components.map((c) => c.code), <String>['3071', '3095']);
    expect(blend.name, '3071 + 3095');
    expect(blend.rgb, isNot(const Rgb(200, 0, 0)));
    await finish(tester);
  });

  testWidgets('правка существующей смеси подгружает цвета ниток из каталога', (tester) async {
    await pumpEditor(tester);
    cubit.addColor(
      PatternColor.blend(
        name: 'Смесь',
        parts: const <BlendPart>[
          BlendPart(
            ref: CatalogRef(brand: 'Гамма', code: '3071'),
            rgb: Rgb(200, 0, 0),
          ),
          BlendPart(
            ref: CatalogRef(brand: 'Гамма', code: '3095'),
            rgb: Rgb(0, 0, 200),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const ValueKey<String>('swatch-2')));
    await tester.pumpAndSettle();

    expect(tester.widget<CupertinoSwitch>(find.byKey(const ValueKey<String>('color-blend'))).value, isTrue);
    expect(find.text('Нитка 2: 3095'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('бусина: первое касание значка выбирает бусину из каталога, затем касание ставит её с цветом', (
    tester,
  ) async {
    await pumpEditor(tester);
    final Finder tool = find.byKey(const ValueKey<String>('tool-bead'));
    await tester.ensureVisible(tool);

    await tester.tap(tool);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey<String>('cat-${_FlossCatalog.miyukiRed.id}')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('color-done')));
    await tester.pumpAndSettle();

    expect(cubit.state.tool, EditorTool.bead);
    expect(cubit.state.activeBead, const CatalogRef(brand: 'Miyuki', code: 'DB0010'));
    await tester.tapAt(tester.getCenter(find.byType(EditorCanvas)));
    await tester.pump();
    expect(cubit.state.layers!.points.single.bead, cubit.state.activeBead);
    expect(cubit.state.beadColors[cubit.state.activeBead], const Rgb(200, 10, 20));
    await finish(tester);
  });

  testWidgets('вставка и удаление ряда в редакторе вышивки не теряют стежки', (tester) async {
    await pumpEditor(tester);
    await selectTool(tester, 'knot');
    cubit.tapPoint(const Offset(1.5, 1.5));

    cubit.insertRow(0);

    expect(cubit.state.layers!.points.single.node, const LatticeNode(3, 5));
    expect(cubit.state.tool, EditorTool.knot);
    await finish(tester);
  });
}
