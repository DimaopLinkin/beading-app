import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/presentation/grid_pattern/grid_pattern_view.dart';
import 'package:beading/presentation/grid_pattern/grid_thumbnail.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/glass_harness.dart';
import 'grid_fixtures.dart';

const Map<String, GridGeometry> _geometries = <String, GridGeometry>{
  'rectangular': GridGeometry.rectangular(),
  'peyote': GridGeometry.peyote(),
  'brick': GridGeometry.brick(),
};

Widget _framed(Widget child) => RepaintBoundary(
  key: const ValueKey<String>('golden'),
  child: ColoredBox(
    color: CupertinoColors.systemBackground.resolveFrom(_ctx!),
    child: SizedBox(width: 340, height: 320, child: child),
  ),
);

BuildContext? _ctx;

void main() {
  for (final MapEntry<String, GridGeometry> geometry in _geometries.entries) {
    for (final Brightness brightness in Brightness.values) {
      for (final bool symbols in <bool>[false, true]) {
        final String name = '${geometry.key}_${brightness.name}${symbols ? '_symbols' : ''}';
        testWidgets('схема $name', (tester) async {
          await pumpGlass(
            tester,
            Builder(
              builder: (context) {
                _ctx = context;
                return _framed(
                  GridPatternView(
                    grid: sampleGrid(),
                    palette: samplePalette(),
                    geometry: geometry.value,
                    metrics: BeadSize.delica11,
                    interactive: false,
                    options: GridViewOptions(
                      showSymbols: symbols,
                      boldEvery: 5,
                      currentRow: symbols ? null : 4,
                      doneRows: symbols ? const <int>{} : const <int>{0, 1, 2, 3},
                      currentCell: symbols ? null : (column: 3, row: 4),
                    ),
                  ),
                );
              },
            ),
            brightness: brightness,
          );
          await tester.pump();
          await expectLater(
            find.byKey(const ValueKey<String>('golden')),
            matchesGoldenFile('goldens/grid_$name.png'),
          );
        });
      }
    }
  }

  for (final Brightness brightness in Brightness.values) {
    testWidgets('схема с маркером ряда, ${brightness.name}', (tester) async {
      final TransformationController controller = TransformationController(
        Matrix4.identity()..scaleByDouble(1.2, 1.2, 1, 1),
      );
      addTearDown(controller.dispose);
      await pumpGlass(
        tester,
        Builder(
          builder: (context) {
            _ctx = context;
            return _framed(
              GridPatternView(
                grid: sampleGrid(),
                palette: samplePalette(),
                geometry: const GridGeometry.rectangular(),
                metrics: BeadSize.delica11,
                controller: controller,
                options: const GridViewOptions(currentRow: 4, doneRows: <int>{0, 1, 2, 3}),
              ),
            );
          },
        ),
        brightness: brightness,
      );
      await tester.pump();
      await expectLater(
        find.byKey(const ValueKey<String>('golden')),
        matchesGoldenFile('goldens/grid_marker_${brightness.name}.png'),
      );
    });
  }

  testWidgets('миниатюра схемы', (tester) async {
    await pumpGlass(
      tester,
      SizedBox(
        key: const ValueKey<String>('golden'),
        width: 120,
        height: 120,
        child: GridThumbnail(
          grid: sampleGrid(width: 30, height: 40),
          palette: samplePalette(),
          geometry: const GridGeometry.peyote(),
          metrics: BeadSize.delica11,
        ),
      ),
    );
    await expectLater(find.byKey(const ValueKey<String>('golden')), matchesGoldenFile('goldens/grid_thumbnail.png'));
  });
}
