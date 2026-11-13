import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/palette_from_generated.dart';
import 'package:beading/domain/image_to_grid/pattern_floss.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final GeneratedPattern pattern = GeneratedPattern(
    grid: Grid.fromCells(width: 10, height: 10, cells: List<int>.filled(100, 1)),
    palette: const <PaletteEntry>[PaletteEntry(rgb: Rgb(200, 10, 10))],
  );
  final PaletteSnapshot palette = paletteFromGenerated(pattern).valueOrNull!;

  test('вышивка: считает мулине по сетке схемы', () {
    final FlossEstimate? estimate = estimateFlossForGenerated(pattern, palette, Fabric.standard);
    expect(estimate, isNotNull);
    expect(estimate!.totalCrossStitches, 100);
    expect(estimate.totalSkeins, greaterThan(0));
  });

  test('бисер: расхода мулине нет', () {
    expect(estimateFlossForGenerated(pattern, palette, BeadSize.delica11), isNull);
  });
}
