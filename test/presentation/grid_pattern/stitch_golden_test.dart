import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/stitch/stitch_legend.dart';
import 'package:beading/presentation/grid_pattern/grid_pattern_view.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/grid_pattern/stitch_legend_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/glass_harness.dart';
import 'stitch_fixtures.dart';

BuildContext? _ctx;

Future<void> _pump(
  WidgetTester tester,
  Brightness brightness,
  GridViewOptions options, {
  bool withLayers = true,
  Fabric? fabric,
}) async {
  await pumpGlass(
    tester,
    Builder(
      builder: (context) {
        _ctx = context;
        return RepaintBoundary(
          key: const ValueKey<String>('golden'),
          child: ColoredBox(
            color: CupertinoColors.systemBackground.resolveFrom(_ctx!),
            child: SizedBox(
              width: 340,
              height: 250,
              child: GridPatternView(
                grid: stitchGrid(),
                palette: stitchPalette(),
                geometry: const GridGeometry.rectangular(),
                metrics: fabric ?? Fabric.standard,
                layers: withLayers ? stitchLayers() : null,
                interactive: false,
                options: options,
              ),
            ),
          ),
        );
      },
    ),
    brightness: brightness,
  );
  await tester.pump();
}

void main() {
  for (final Brightness brightness in Brightness.values) {
    for (final StitchStyle style in StitchStyle.values) {
      testWidgets('вышивка, стиль ${style.name}, ${brightness.name}', (tester) async {
        await _pump(tester, brightness, GridViewOptions(stitchStyle: style, boldEvery: 5));
        await expectLater(
          find.byKey(const ValueKey<String>('golden')),
          matchesGoldenFile('goldens/stitch_${style.name}_${brightness.name}.png'),
        );
      });
    }

    testWidgets('вышивка как будет выглядеть, кремовая канва, ${brightness.name}', (tester) async {
      await _pump(tester, brightness, const GridViewOptions(realistic: true), fabric: cream());
      await expectLater(
        find.byKey(const ValueKey<String>('golden')),
        matchesGoldenFile('goldens/stitch_realistic_${brightness.name}.png'),
      );
    });

    testWidgets('легенда вышивки, ${brightness.name}', (tester) async {
      await pumpGlass(
        tester,
        Builder(
          builder: (context) => RepaintBoundary(
            key: const ValueKey<String>('golden'),
            child: ColoredBox(
              color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
              child: SizedBox(
                width: 380,
                height: 560,
                child: StitchLegendView(
                  entries: StitchLegend.build(grid: stitchGrid(), palette: stitchPalette(), layers: stitchLayers()),
                  selected: 3,
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        ),
        brightness: brightness,
      );
      await tester.pump();
      await expectLater(
        find.byKey(const ValueKey<String>('golden')),
        matchesGoldenFile('goldens/stitch_legend_${brightness.name}.png'),
      );
    });

    testWidgets('вышивка: подсветка цвета, центр, сделанные клетки, ${brightness.name}', (tester) async {
      await _pump(
        tester,
        brightness,
        GridViewOptions(
          stitchStyle: StitchStyle.colorAndSymbol,
          boldEvery: 10,
          highlightColor: 3,
          showCenter: true,
          doneCells: <CellPosition>{for (int c = 0; c < 14; c++) CellPosition(c, 1)},
          hiddenLayers: const <StitchLayerKind>{StitchLayerKind.points},
        ),
        fabric: Fabric.standard.withColor(const Rgb(214, 226, 240)),
      );
      await expectLater(
        find.byKey(const ValueKey<String>('golden')),
        matchesGoldenFile('goldens/stitch_marks_${brightness.name}.png'),
      );
    });
  }
}
