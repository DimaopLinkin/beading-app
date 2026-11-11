import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_legend.dart';
import 'package:beading/presentation/grid_pattern/grid_layer_cache.dart';
import 'package:beading/presentation/grid_pattern/grid_pattern_view.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/grid_pattern/stitch_legend_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/glass_harness.dart';
import 'stitch_fixtures.dart';

Widget _view({
  StitchLayers? layers,
  GridViewOptions options = const GridViewOptions(),
  GridLayerCache? cache,
  bool beads = false,
}) => SizedBox(
  width: 360,
  height: 300,
  child: GridPatternView(
    grid: stitchGrid(),
    palette: stitchPalette(),
    geometry: const GridGeometry.rectangular(),
    metrics: beads ? BeadSize.delica11 : Fabric.standard,
    layers: layers,
    options: options,
    layerCache: cache,
  ),
);

const Key _layersKey = ValueKey<String>('stitch-layers');

void main() {
  testWidgets('слой вышивки рисуется только когда в слоях что-то есть', (tester) async {
    await pumpGlass(tester, _view());
    expect(find.byKey(_layersKey), findsNothing);
    await pumpGlass(tester, _view(layers: StitchLayers.empty(columns: 14, rows: 10)));
    expect(find.byKey(_layersKey), findsNothing);
    await pumpGlass(tester, _view(layers: stitchLayers()));
    expect(find.byKey(_layersKey), findsOneWidget);
  });

  testWidgets('смена слоёв и скрытых слоёв не пересобирает клетки', (tester) async {
    final GridLayerCache cache = GridLayerCache();
    addTearDown(cache.dispose);
    await pumpGlass(tester, _view(layers: stitchLayers(), cache: cache));
    final int built = cache.buildCount;
    expect(built, greaterThan(0));
    await pumpGlass(
      tester,
      _view(
        layers: stitchLayers().rebuilt(lines: const []),
        options: const GridViewOptions(
          hiddenLayers: <StitchLayerKind>{StitchLayerKind.points},
          showCenter: true,
        ),
        cache: cache,
      ),
    );
    expect(cache.buildCount, built);
  });

  testWidgets('смена сложений нити и подсветка цвета пересобирают клетки', (tester) async {
    final GridLayerCache cache = GridLayerCache();
    addTearDown(cache.dispose);
    await pumpGlass(tester, _view(layers: stitchLayers(), cache: cache));
    final int built = cache.buildCount;
    await pumpGlass(
      tester,
      _view(
        layers: stitchLayers().rebuilt(defaultSpec: stitchLayers().defaultSpec.copyWith(crossStrands: 5)),
        cache: cache,
      ),
    );
    final int afterStrands = cache.buildCount;
    expect(afterStrands, greaterThan(built));
    await pumpGlass(
      tester,
      _view(
        layers: stitchLayers().rebuilt(defaultSpec: stitchLayers().defaultSpec.copyWith(crossStrands: 5)),
        options: const GridViewOptions(highlightColor: 2),
        cache: cache,
      ),
    );
    expect(cache.buildCount, greaterThan(afterStrands));
  });

  testWidgets('смена сложений бэкстича не пересобирает клетки', (tester) async {
    final GridLayerCache cache = GridLayerCache();
    addTearDown(cache.dispose);
    await pumpGlass(tester, _view(layers: stitchLayers(), cache: cache));
    final int built = cache.buildCount;
    final StitchLayers l = stitchLayers();
    await pumpGlass(
      tester,
      _view(
        layers: l.rebuilt(defaultSpec: l.defaultSpec.copyWith(backstitchStrands: 3)),
        cache: cache,
      ),
    );
    expect(cache.buildCount, built);
  });

  testWidgets('центр и сделанные клетки рисуются поверх, слой клеток не трогают', (tester) async {
    final GridLayerCache cache = GridLayerCache();
    addTearDown(cache.dispose);
    await pumpGlass(tester, _view(cache: cache));
    final int built = cache.buildCount;
    await pumpGlass(
      tester,
      _view(
        cache: cache,
        options: GridViewOptions(showCenter: true, doneCells: <CellPosition>{const CellPosition(0, 0)}),
      ),
    );
    expect(cache.buildCount, built);
    expect(find.byKey(const ValueKey<String>('grid-overlay')), findsOneWidget);
  });

  testWidgets('бисерная схема со слоями не ломается и рисует клетки как раньше', (tester) async {
    await pumpGlass(tester, _view(beads: true, options: const GridViewOptions(highlightColor: 2)));
    expect(tester.takeException(), isNull);
  });

  group('легенда', () {
    final List<StitchLegendEntry> entries = StitchLegend.build(
      grid: stitchGrid(),
      palette: stitchPalette(),
      layers: stitchLayers(),
    );

    testWidgets('показывает нить, название, сложения и число крестиков', (tester) async {
      await pumpGlass(tester, StitchLegendView(entries: entries));
      expect(find.text('DMC 310'), findsOneWidget);
      expect(find.textContaining('Чёрный'), findsOneWidget);
      // Красная нить: крестик в 3 нитки (переопределено в слоях), неполные стежки и бэкстич.
      expect(find.textContaining('крестик в 3 нитки'), findsOneWidget);
      expect(find.textContaining('бэкстич'), findsWidgets);
      expect(find.textContaining('крестик'), findsWidgets);
    });

    testWidgets('мотки показаны, когда легенда построена с расчётом мулине', (tester) async {
      final FlossEstimate floss = FlossEstimator(
        fabric: Fabric.standard,
        layers: stitchLayers(),
      ).estimate(stitchGrid(), stitchPalette());
      await pumpGlass(
        tester,
        StitchLegendView(
          entries: StitchLegend.build(
            grid: stitchGrid(),
            palette: stitchPalette(),
            layers: stitchLayers(),
            floss: floss,
          ),
        ),
      );
      expect(find.textContaining('1 моток'), findsWidgets);
    });

    testWidgets('касание подсвечивает цвет, повторное снимает', (tester) async {
      final List<int?> taps = <int?>[];
      await pumpGlass(tester, StitchLegendView(entries: entries, onSelect: taps.add));
      await tester.tap(find.byKey(const ValueKey<String>('legend-3')));
      expect(taps, <int?>[3]);
      await pumpGlass(tester, StitchLegendView(entries: entries, selected: 3, onSelect: taps.add));
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('legend-3')));
      expect(taps, <int?>[3, null]);
    });

    testWidgets('цвета без стежков скрыты, пока их не попросили показать', (tester) async {
      final List<StitchLegendEntry> withUnused = StitchLegend.build(
        grid: Grid.fromCells(width: 14, height: 10, cells: List<int>.filled(140, 1)),
        palette: stitchPalette(),
      );
      await pumpGlass(tester, StitchLegendView(entries: withUnused));
      expect(find.byKey(const ValueKey<String>('legend-2')), findsNothing);
      await pumpGlass(tester, StitchLegendView(entries: withUnused, showUnused: true));
      expect(find.byKey(const ValueKey<String>('legend-2')), findsOneWidget);
    });

    testWidgets('пустая палитра: понятная подпись', (tester) async {
      await pumpGlass(tester, const StitchLegendView(entries: <StitchLegendEntry>[]));
      expect(find.text('В схеме пока нет ни одной нитки.'), findsOneWidget);
    });
  });
}
