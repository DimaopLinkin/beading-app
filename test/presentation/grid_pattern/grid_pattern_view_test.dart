import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/presentation/grid_pattern/grid_base_painter.dart';
import 'package:beading/presentation/grid_pattern/grid_layer_cache.dart';
import 'package:beading/presentation/grid_pattern/grid_pattern_view.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/glass_harness.dart';
import 'grid_fixtures.dart';

Widget _view({
  Grid? grid,
  PaletteSnapshot? palette,
  GridGeometry geometry = const GridGeometry.rectangular(),
  GridViewOptions options = const GridViewOptions(),
  TransformationController? controller,
  ValueChanged<CellPosition>? onTap,
  GridLayerCache? cache,
}) => SizedBox(
  width: 360,
  height: 640,
  child: GridPatternView(
    grid: grid ?? sampleGrid(),
    palette: palette ?? samplePalette(),
    geometry: geometry,
    metrics: BeadSize.delica11,
    options: options,
    controller: controller,
    onCellTap: onTap,
    layerCache: cache,
  ),
);

GridBasePainter _basePainter(WidgetTester tester) {
  final CustomPaint paint = tester.widget(find.byKey(const ValueKey<String>('grid-cells')));
  return paint.painter! as GridBasePainter;
}

void main() {
  testWidgets('касание отдаёт ячейку под пальцем при зуме 1×', (tester) async {
    final List<CellPosition> taps = <CellPosition>[];
    final TransformationController controller = TransformationController();
    addTearDown(controller.dispose);
    await pumpGlass(tester, _view(onTap: taps.add, controller: controller));
    final GridScene scene = GridScene(
      geometry: const GridGeometry.rectangular(),
      metrics: BeadSize.delica11,
      columns: 12,
      rows: 10,
    );
    final Offset origin = tester.getTopLeft(find.byKey(const ValueKey<String>('grid-touch')));
    await tester.tapAt(origin + scene.cellRect(const CellPosition(3, 4)).center);
    expect(taps, <CellPosition>[const CellPosition(3, 4)]);
  });

  testWidgets('касание попадает в нужную ячейку при зуме и сдвиге', (tester) async {
    final List<CellPosition> taps = <CellPosition>[];
    final TransformationController controller = TransformationController(
      Matrix4.identity()
        ..translateByDouble(-50, -30, 0, 1)
        ..scaleByDouble(2.5, 2.5, 1, 1),
    );
    addTearDown(controller.dispose);
    await pumpGlass(tester, _view(onTap: taps.add, controller: controller));
    final GridScene scene = GridScene(
      geometry: const GridGeometry.rectangular(),
      metrics: BeadSize.delica11,
      columns: 12,
      rows: 10,
    );
    final Rect cell = scene.cellRect(const CellPosition(5, 6));
    final Offset screen = MatrixUtils.transformPoint(controller.value, cell.center);
    final Offset origin = tester.getTopLeft(find.byType(GridPatternView));
    await tester.tapAt(origin + screen);
    expect(taps, <CellPosition>[const CellPosition(5, 6)]);
  });

  testWidgets('касание за схемой ничего не отдаёт', (tester) async {
    final List<CellPosition> taps = <CellPosition>[];
    final TransformationController controller = TransformationController();
    addTearDown(controller.dispose);
    await pumpGlass(tester, _view(onTap: taps.add, controller: controller, geometry: const GridGeometry.peyote()));
    final Offset origin = tester.getTopLeft(find.byType(GridPatternView));
    // Ниже последней ячейки: в сцене пустота.
    await tester.tapAt(origin + const Offset(5, 620));
    expect(taps, isEmpty);
  });

  testWidgets('перерисовка без изменений не строит блоки заново', (tester) async {
    final Grid grid = sampleGrid(width: 100, height: 400);
    final PaletteSnapshot palette = samplePalette();
    final TransformationController controller = TransformationController();
    addTearDown(controller.dispose);
    final GridLayerCache cache = GridLayerCache();
    addTearDown(cache.dispose);
    Widget build() => _view(grid: grid, palette: palette, controller: controller, cache: cache);

    await pumpGlass(tester, build());
    final int built = cache.buildCount;
    expect(built, greaterThan(0));
    expect(built, lessThan(30), reason: 'строятся только видимые блоки, а не вся схема 100×400');

    // Родитель перестроился, схема та же (в том числе равная, но не тождественная копия).
    await pumpGlass(
      tester,
      _view(
        grid: Grid.fromCells(width: 100, height: 400, cells: grid.cells.toList()),
        palette: palette,
        controller: controller,
        cache: cache,
      ),
    );
    // Сдвиг в пределах уже построенных блоков.
    controller.value = Matrix4.identity()..translateByDouble(0, -4, 0, 1);
    await tester.pump();
    expect(cache.buildCount, built);
  });

  testWidgets('смена схемы пересобирает блоки', (tester) async {
    final TransformationController controller = TransformationController();
    addTearDown(controller.dispose);
    final GridLayerCache cache = GridLayerCache();
    addTearDown(cache.dispose);
    await pumpGlass(tester, _view(controller: controller, cache: cache));
    final int built = cache.buildCount;
    await pumpGlass(tester, _view(grid: sampleGrid().withCell(0, 0, 3), controller: controller, cache: cache));
    await tester.pump();
    expect(cache.buildCount, greaterThan(built));
  });

  testWidgets('подсветка ряда не сбрасывает кеш ячеек', (tester) async {
    final Grid grid = sampleGrid();
    final PaletteSnapshot palette = samplePalette();
    final TransformationController controller = TransformationController();
    addTearDown(controller.dispose);
    final GridLayerCache cache = GridLayerCache();
    addTearDown(cache.dispose);
    await pumpGlass(tester, _view(grid: grid, palette: palette, controller: controller, cache: cache));
    final int built = cache.buildCount;
    await pumpGlass(
      tester,
      _view(
        grid: grid,
        palette: palette,
        controller: controller,
        cache: cache,
        options: const GridViewOptions(currentRow: 3, doneRows: <int>{0, 1, 2}),
      ),
    );
    await tester.pump();
    expect(cache.buildCount, built);
  });

  testWidgets('режим символов пересобирает слой', (tester) async {
    final TransformationController controller = TransformationController();
    addTearDown(controller.dispose);
    final GridLayerCache cache = GridLayerCache();
    addTearDown(cache.dispose);
    await pumpGlass(tester, _view(controller: controller, cache: cache));
    final int built = cache.buildCount;
    await pumpGlass(
      tester,
      _view(controller: controller, cache: cache, options: const GridViewOptions(showSymbols: true)),
    );
    await tester.pump();
    expect(cache.buildCount, greaterThan(built));
  });

  testWidgets('маркер текущего ряда показывает номер с единицы и пропадает без ряда', (tester) async {
    await pumpGlass(tester, _view(options: const GridViewOptions(currentRow: 2)));
    await tester.pump();
    expect(
      find.text(AppLocalizations.of(tester.element(find.byType(GridPatternView))).gridRowMarker(3)),
      findsOneWidget,
    );
    await pumpGlass(tester, _view());
    expect(find.byKey(const ValueKey<String>('grid-row-marker')), findsNothing);
  });

  testWidgets('painter слоя ячеек не перерисовывается без смены данных', (tester) async {
    await pumpGlass(tester, _view());
    final GridBasePainter first = _basePainter(tester);
    await pumpGlass(tester, _view());
    final GridBasePainter second = _basePainter(tester);
    expect(second.shouldRepaint(first), isFalse);
  });

  testWidgets('неинтерактивный вид строит всю схему, а не окно', (tester) async {
    final GridLayerCache cache = GridLayerCache();
    addTearDown(cache.dispose);
    await pumpGlass(
      tester,
      SizedBox(
        width: 360,
        height: 640,
        child: GridPatternView(
          grid: sampleGrid(width: 100, height: 400),
          palette: samplePalette(),
          geometry: const GridGeometry.rectangular(),
          metrics: BeadSize.delica11,
          interactive: false,
          layerCache: cache,
        ),
      ),
    );
    // 100×400 ячеек = 4×13 блоков по 32.
    expect(cache.buildCount, 4 * 13);
  });
}
