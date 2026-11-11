import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/cell_costs.dart';
import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/lab.dart';

/// Результат разметки: номера цветов клеток (`1..`, `0` — пустая клетка) и цены всех цветов.
final class LabeledCells {
  const LabeledCells({required this.values, required this.costs});

  final Uint16List values;
  final CellCosts costs;
}

/// Стадия 3 конвейера (ADR-0004): цена каждого цвета для каждой клетки и начальные номера.
abstract interface class CellLabeler {
  LabeledCells label({required WorkImage work, required CellRegions regions, required List<Lab> palette});
}

/// Цвет клетки голосованием пикселей: цена цвета — средняя Евклидова разница в Lab его до рабочих пикселей клетки,
/// клетка берёт цвет с минимальной ценой.
///
/// На границе двух областей 60/40 это цвет большей части, а не «грязная» смесь, которой нет в палитре.
final class VotingCellLabeler implements CellLabeler {
  const VotingCellLabeler();

  /// Клетка с долей непрозрачности ниже этой пуста (как в CellSampler).
  static const double emptyBelowAlpha = 0.5;

  @override
  LabeledCells label({required WorkImage work, required CellRegions regions, required List<Lab> palette}) {
    final int cells = regions.columns * regions.rows;
    final int k = palette.length;
    final Float32List costs = Float32List(cells * k);
    final Uint16List values = Uint16List(cells);
    if (k == 0) {
      return LabeledCells(
        values: values,
        costs: CellCosts(columns: regions.columns, rows: regions.rows, colorCount: 0, values: costs),
      );
    }
    final Float64List pl = Float64List.fromList(<double>[for (final Lab c in palette) c.l]);
    final Float64List pa = Float64List.fromList(<double>[for (final Lab c in palette) c.a]);
    final Float64List pb = Float64List.fromList(<double>[for (final Lab c in palette) c.b]);
    final Float64List sum = Float64List(k);
    for (int cell = 0; cell < cells; cell++) {
      sum.fillRange(0, k, 0);
      double alphaSum = 0;
      int area = 0;
      int counted = 0;
      for (int y = regions.top(cell); y < regions.bottom(cell); y++) {
        for (int x = regions.left(cell); x < regions.right(cell); x++) {
          final int p = y * work.width + x;
          area++;
          alphaSum += work.alpha[p];
          if (work.alpha[p] < emptyBelowAlpha) continue;
          counted++;
          final double l = work.lightness[p];
          final double a = work.a[p];
          final double b = work.b[p];
          for (int c = 0; c < k; c++) {
            final double dl = l - pl[c];
            final double da = a - pa[c];
            final double db = b - pb[c];
            sum[c] += math.sqrt(dl * dl + da * da + db * db);
          }
        }
      }
      if (area == 0 || counted == 0 || alphaSum / area < emptyBelowAlpha) continue;
      int best = 0;
      for (int c = 0; c < k; c++) {
        final double cost = sum[c] / counted;
        costs[cell * k + c] = cost;
        if (cost < costs[cell * k + best]) best = c;
      }
      values[cell] = best + 1;
    }
    return LabeledCells(
      values: values,
      costs: CellCosts(columns: regions.columns, rows: regions.rows, colorCount: k, values: costs),
    );
  }
}
