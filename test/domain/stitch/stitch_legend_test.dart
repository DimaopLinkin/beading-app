import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:beading/domain/stitch/point_stitch.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_legend.dart';
import 'package:beading/domain/stitch/stitch_spec.dart';
import 'package:flutter_test/flutter_test.dart';

PatternColor _c(String code) => PatternColor(
  rgb: const Rgb(10, 20, 30),
  name: code,
  components: <CatalogRef>[CatalogRef(brand: 'DMC', code: code)],
);

void main() {
  final PaletteSnapshot palette = PaletteSnapshot(<PatternColor>[_c('310'), _c('666'), _c('white')]);
  final Grid grid = Grid.fromCells(width: 3, height: 2, cells: <int>[1, 1, 2, 0, 1, 2]);

  test('считает полные крестики по цветам палитры', () {
    final List<StitchLegendEntry> entries = StitchLegend.build(grid: grid, palette: palette);
    expect(entries.map((e) => e.crosses), <int>[3, 2, 0]);
    expect(entries.map((e) => e.gridValue), <int>[1, 2, 3]);
    expect(entries[2].isUnused, isTrue);
  });

  test('без слоёв: сложения по умолчанию, ни неполных, ни бэкстича', () {
    final StitchLegendEntry first = StitchLegend.build(grid: grid, palette: palette).first;
    expect(first.spec, const StitchSpec());
    expect(first.partials, 0);
    expect(first.backstitchLength, 0);
    expect(first.knots, 0);
  });

  test('считает неполные, длину бэкстича в клетках, узелки; бусины не считаются', () {
    final StitchLayers layers = StitchLayers(
      columns: 3,
      rows: 2,
      colorSpecs: const <int, StitchSpec>{2: StitchSpec(crossStrands: 3, backstitchStrands: 2)},
      partials: <PartialStitch>[
        PartialStitch(column: 0, row: 0, kind: PartialKind.half, orientation: StitchOrientation.slash, color: 3),
        PartialStitch(column: 1, row: 0, kind: PartialKind.quarter, orientation: StitchOrientation.topLeft, color: 3),
      ],
      lines: <LineStitch>[
        // Две клетки по горизонтали и клетка по диагонали (два полушага).
        LineStitch(a: const LatticeNode(0, 0), b: const LatticeNode(4, 0), kind: LineKind.backstitch, color: 2),
        LineStitch(a: const LatticeNode(0, 2), b: const LatticeNode(2, 4), kind: LineKind.straight, color: 2),
      ],
      points: <PointStitch>[
        PointStitch.knot(node: const LatticeNode(1, 1), kind: PointKind.frenchKnot, color: 1),
        PointStitch.bead(
          node: const LatticeNode(3, 1),
          bead: const CatalogRef(brand: 'Miyuki', code: '11-1'),
        ),
      ],
    );
    final List<StitchLegendEntry> entries = StitchLegend.build(grid: grid, palette: palette, layers: layers);
    expect(entries[2].partials, 2);
    expect(entries[1].backstitchLength, closeTo(2 + 1.4142, 0.001));
    expect(entries[1].spec.crossStrands, 3);
    expect(entries[0].knots, 1);
    expect(entries.fold<int>(0, (s, e) => s + e.knots), 1);
    expect(entries[2].isUnused, isFalse);
  });
}
