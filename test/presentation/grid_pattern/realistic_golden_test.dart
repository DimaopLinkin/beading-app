import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/presentation/grid_pattern/grid_pattern_view.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/glass_harness.dart';
import 'grid_fixtures.dart';

final class _Aida implements CellMetrics {
  const _Aida();

  @override
  double get widthMm => 2.5;

  @override
  double get heightMm => 2.5;
}

typedef _Case = ({GridGeometry geometry, CellMetrics metrics});

const Map<String, _Case> _cases = <String, _Case>{
  'loom': (geometry: GridGeometry.rectangular(), metrics: BeadSize.delica11),
  'peyote': (geometry: GridGeometry.peyote(), metrics: BeadSize.delica11),
  'brick': (geometry: GridGeometry.brick(), metrics: BeadSize.delica11),
  'rocaille': (geometry: GridGeometry.rectangular(), metrics: BeadSize.rocaille11),
  'stitch': (geometry: GridGeometry.rectangular(), metrics: _Aida()),
};

BuildContext? _ctx;

void main() {
  for (final MapEntry<String, _Case> entry in _cases.entries) {
    for (final Brightness brightness in Brightness.values) {
      testWidgets('как будет выглядеть: ${entry.key}, ${brightness.name}', (tester) async {
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
                    height: 320,
                    child: GridPatternView(
                      grid: sampleGrid(),
                      palette: samplePalette(),
                      geometry: entry.value.geometry,
                      metrics: entry.value.metrics,
                      interactive: false,
                      options: const GridViewOptions(realistic: true),
                    ),
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
          matchesGoldenFile('goldens/realistic_${entry.key}_${brightness.name}.png'),
        );
      });
    }
  }
}
