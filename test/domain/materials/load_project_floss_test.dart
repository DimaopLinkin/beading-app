import 'package:beading/core/failure.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/domain/materials/use_cases/load_project_floss.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_layers_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_grid_pattern.dart';

GridPattern _stitchPattern({StitchLayers? layers}) => GridPattern(
  id: 'pat-1',
  projectId: 'proj-1',
  geometry: const RectangularGeometry(),
  metrics: Fabric.standard,
  grid: Grid.fromCells(width: 2, height: 1, cells: const <int>[1, 1]),
  palette: PaletteSnapshot(<PatternColor>[
    PatternColor(
      rgb: const Rgb(200, 0, 0),
      name: 'Красный',
      components: const <CatalogRef>[CatalogRef(brand: 'Гамма', code: '3071')],
    ),
  ]),
  layers: layers == null ? null : StitchLayersCodec.toBlob(layers),
);

void main() {
  late FakeGridPatternRepository patterns;

  setUp(() => patterns = FakeGridPatternRepository());

  test('вышивка без слоёв: считает крестики, покупки по Гамме', () async {
    patterns.byProject['proj-1'] = _stitchPattern();

    final FlossEstimate estimate = (await LoadProjectFloss(patterns)('proj-1')).valueOrNull!;

    expect(estimate.totalCrossStitches, 2);
    expect(estimate.purchases.single.ref, const CatalogRef(brand: 'Гамма', code: '3071'));
    expect(estimate.totalSkeins, 1);
  });

  test('слои сохранённой схемы входят в расход', () async {
    final StitchLayers layers = StitchLayers(
      columns: 2,
      rows: 1,
      lines: <LineStitch>[
        LineStitch(a: const LatticeNode(0, 0), b: const LatticeNode(4, 0), kind: LineKind.backstitch, color: 1),
      ],
    );
    patterns.byProject['proj-1'] = _stitchPattern(layers: layers);
    final FlossEstimate plain = (await LoadProjectFloss(patterns)('proj-1', reserve: 0)).valueOrNull!;
    patterns.byProject['proj-1'] = _stitchPattern();
    final FlossEstimate without = (await LoadProjectFloss(patterns)('proj-1', reserve: 0)).valueOrNull!;

    expect(plain.lines.single.backstitchCells, 2);
    expect(plain.lines.single.strandMeters, greaterThan(without.lines.single.strandMeters));
  });

  test('бисерная схема — ValidationFailure', () async {
    patterns.byProject['proj-1'] = sampleGridPattern();

    expect((await LoadProjectFloss(patterns)('proj-1')).failureOrNull, isA<ValidationFailure>());
  });

  test('схемы нет — NotFoundFailure', () async {
    expect((await LoadProjectFloss(patterns)('нет')).failureOrNull, isA<NotFoundFailure>());
  });

  test('цвет сетки вне палитры — ValidationFailure', () async {
    final GridPattern good = _stitchPattern();
    patterns.byProject['proj-1'] = good.copyWith(palette: PaletteSnapshot(const <PatternColor>[]));

    expect((await LoadProjectFloss(patterns)('proj-1')).failureOrNull, isA<ValidationFailure>());
  });
}
