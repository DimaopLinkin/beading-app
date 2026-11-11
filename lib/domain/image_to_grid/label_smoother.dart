import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/cell_costs.dart';
import 'package:beading/domain/image_to_grid/cell_neighbors.dart';

/// Стадия 4 конвейера (ADR-0004): сглаживание разметки по ценам цветов.
abstract interface class LabelSmoother {
  /// Новые номера цветов клеток (`1..`, `0` — пустая клетка, остаётся пустой).
  ///
  /// [edges] — сила края в клетке (`cellEdges`), [importance] — вес важности клетки.
  Uint16List smooth({
    required Uint16List values,
    required CellCosts costs,
    required CellNeighbors neighbors,
    required Float32List importance,
    required Float32List edges,
  });
}

/// Модель Поттса, ICM (обновление на месте, без дрожания на шахматках): клетка берёт цвет с наименьшей суммой «цена цвета для клетки + λ × число соседей другого цвета».
///
/// λ адаптивна: на однотонных местах больше (шум убирается), на сильных краях и под маской важности меньше (детали
/// остаются). [detail] от 0 («гладко») до 1 («детально») двигает λ целиком: это ползунок «детальность ↔ гладкость».
final class PottsLabelSmoother implements LabelSmoother {
  const PottsLabelSmoother({this.detail = 0.5, this.iterations = 4, this.edgeScale = 12})
    : assert(detail >= 0 && detail <= 1, 'detail от 0 до 1'),
      assert(iterations >= 1, 'iterations не меньше 1'),
      assert(edgeScale > 0, 'edgeScale больше 0');

  final double detail;
  final int iterations;

  /// Перепад Lab, при котором λ падает вдвое.
  final double edgeScale;

  /// λ клетки: базовая по детальности, делённая на важность и ослабленная краем.
  double lambdaFor({required double edge, required double importance}) {
    final double flatness = 1 / (1 + edge / edgeScale);
    return (0.6 + 2.4 * (1 - detail)) * flatness / (importance <= 0.01 ? 0.01 : importance);
  }

  @override
  Uint16List smooth({
    required Uint16List values,
    required CellCosts costs,
    required CellNeighbors neighbors,
    required Float32List importance,
    required Float32List edges,
  }) {
    final int cells = values.length;
    final int k = costs.colorCount;
    final Uint16List current = Uint16List.fromList(values);
    if (k < 2) return current;
    final Float64List lambda = Float64List(cells);
    for (int i = 0; i < cells; i++) {
      lambda[i] = lambdaFor(edge: edges[i], importance: importance[i]);
    }
    final Float64List votes = Float64List(k);
    for (int pass = 0; pass < iterations; pass++) {
      bool changed = false;
      for (int cell = 0; cell < cells; cell++) {
        if (current[cell] == 0) continue;
        // Штраф цвета c: число непустых соседей не этого цвета; считаем «голоса» соседей и вычитаем.
        votes.fillRange(0, k, 0);
        int filled = 0;
        for (int n = 0; n < neighbors.count(cell); n++) {
          final int v = current[neighbors.at(cell, n)];
          if (v == 0) continue;
          votes[v - 1] += 1;
          filled++;
        }
        int best = current[cell] - 1;
        double bestScore = double.infinity;
        for (int c = 0; c < k; c++) {
          final double score = costs.at(cell, c) + lambda[cell] * (filled - votes[c]);
          // При равенстве остаёмся при своём цвете: без дрожания между двумя равными вариантами.
          if (score < bestScore - 1e-9 || (score < bestScore + 1e-9 && c == current[cell] - 1)) {
            bestScore = score;
            best = c;
          }
        }
        if (best != current[cell] - 1) {
          current[cell] = best + 1;
          changed = true;
        }
      }
      if (!changed) break;
    }
    return current;
  }
}
