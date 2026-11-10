import 'package:beading/core/failure.dart';
import 'package:beading/domain/grid_pattern/cell_metrics_codec.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/materials/bead_estimate.dart';
import 'package:beading/domain/materials/use_cases/load_project_materials.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_grid_pattern.dart';

void main() {
  late FakeGridPatternRepository patterns;

  setUp(() => patterns = FakeGridPatternRepository());

  test('считает бисер по сетке и палитре проекта: штуки, граммы и запас 10%', () async {
    patterns.byProject['proj-1'] = sampleGridPattern();

    final BeadEstimate estimate = (await LoadProjectMaterials(patterns)('proj-1')).valueOrNull!;

    // В схеме 5 бусин первого цвета и 4 второго; Delica 11/0 — 0,005 г.
    expect(estimate.lines.map((l) => (l.colorIndex, l.pieces, l.piecesWithReserve)), <(int, int, int)>[
      (1, 5, 6),
      (2, 4, 5),
    ]);
    expect(estimate.totalPieces, 9);
    expect(estimate.totalGrams, closeTo(0.045, 1e-9));
    expect(estimate.reserve, BeadEstimator.defaultReserve);
  });

  test('запас можно задать', () async {
    patterns.byProject['proj-1'] = sampleGridPattern();

    final BeadEstimate estimate = (await LoadProjectMaterials(patterns)('proj-1', reserve: 0)).valueOrNull!;

    expect(estimate.totalPiecesWithReserve, estimate.totalPieces);
  });

  test('у проекта нет схемы — NotFoundFailure', () async {
    expect((await LoadProjectMaterials(patterns)('нет')).failureOrNull, isA<NotFoundFailure>());
  });

  test('произвольный размер ячейки: вес неизвестен, ValidationFailure', () async {
    patterns.byProject['proj-1'] = sampleGridPattern().copyWith(
      metrics: const CustomCellMetrics(widthMm: 2, heightMm: 3),
    );

    expect((await LoadProjectMaterials(patterns)('proj-1')).failureOrNull, isA<ValidationFailure>());
  });

  test('цвет сетки вне палитры — ValidationFailure, а не исключение', () async {
    final GridPattern good = sampleGridPattern();
    patterns.byProject['proj-1'] = good.copyWith(palette: PaletteSnapshot(good.palette.colors.take(1).toList()));

    expect((await LoadProjectMaterials(patterns)('proj-1')).failureOrNull, isA<ValidationFailure>());
  });
}
