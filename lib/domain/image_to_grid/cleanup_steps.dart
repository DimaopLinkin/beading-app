import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/cell_costs.dart';
import 'package:beading/domain/image_to_grid/cell_neighbors.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';
import 'package:beading/domain/palette/lab.dart';

/// Шаг «острова» (стадия 5): связные области цвета меньше [minIsland] клеток перекрашиваются в соседний цвет с
/// наименьшей ценой для этих клеток.
///
/// Не трогает: области, где есть клетка под маской «важное» (вес больше [protectImportance]) или с краем в верхних
/// [protectEdgeShare] долях клеток (глаза, блики), и тонкие линии — цепочки шириной в одну клетку длиной от трёх.
final class RemoveIslandsStep implements PatternStep {
  const RemoveIslandsStep({this.minIsland = 3, this.protectEdgeShare = 0.05, this.protectImportance = 3})
    : assert(minIsland >= 2, 'minIsland не меньше 2'),
      assert(protectEdgeShare >= 0 && protectEdgeShare <= 1, 'protectEdgeShare от 0 до 1');

  final int minIsland;
  final double protectEdgeShare;
  final double protectImportance;

  @override
  GeneratedPattern apply(GeneratedPattern pattern, PatternStepContext context) {
    final Grid grid = pattern.grid;
    final int columns = grid.width;
    final int rows = grid.height;
    final CellNeighbors neighbors = CellNeighbors.of(geometry: context.geometry, columns: columns, rows: rows);
    final Uint16List values = _values(grid);
    final Uint16List out = Uint16List.fromList(values);
    final double edgeLimit = _edgeLimit(context.cellEdges, values);
    final CellCosts? costs = context.costs;
    final List<Lab> paletteLab = <Lab>[for (final e in pattern.palette) Lab.fromRgb(e.rgb)];

    final Uint8List seen = Uint8List(values.length);
    final List<int> component = <int>[];
    for (int start = 0; start < values.length; start++) {
      if (seen[start] == 1 || values[start] == 0) continue;
      _collect(values, neighbors, start, seen, component);
      if (component.length >= minIsland) continue;
      if (_isProtected(component, context, edgeLimit) || _isThinLine(component, values, neighbors)) continue;
      final int? target = _bestNeighbor(component, values, neighbors, costs, paletteLab);
      if (target == null) continue;
      for (final int cell in component) {
        out[cell] = target;
      }
    }
    return GeneratedPattern(grid: _grid(grid, out), palette: pattern.palette, stats: pattern.stats);
  }

  bool _isProtected(List<int> component, PatternStepContext context, double edgeLimit) {
    final Float32List? edges = context.cellEdges;
    for (final int cell in component) {
      if (context.cellImportance[cell] > protectImportance) return true;
      if (context.faces?.isFeature(cell) ?? false) return true;
      if (edges != null && edges[cell] >= edgeLimit) return true;
    }
    return false;
  }

  /// Порог края: клетки сильнее него — «детали». Без краёв порог недостижим.
  double _edgeLimit(Float32List? edges, Uint16List values) {
    if (edges == null || protectEdgeShare <= 0) return double.infinity;
    final List<double> sorted = <double>[
      for (int i = 0; i < values.length; i++)
        if (values[i] != 0) edges[i],
    ]..sort();
    if (sorted.isEmpty) return double.infinity;
    final int index = ((sorted.length - 1) * (1 - protectEdgeShare)).floor();
    if (sorted.last <= 0) return double.infinity; // совсем ровная картинка ничего не защищает
    // Если сильных краёв меньше доли, порог — самый слабый ненулевой край.
    return sorted[index] > 0 ? sorted[index] : sorted.firstWhere((e) => e > 0);
  }

  int? _bestNeighbor(
    List<int> component,
    Uint16List values,
    CellNeighbors neighbors,
    CellCosts? costs,
    List<Lab> paletteLab,
  ) {
    final int own = values[component.first];
    final Set<int> candidates = <int>{};
    for (final int cell in component) {
      for (int n = 0; n < neighbors.count(cell); n++) {
        final int v = values[neighbors.at(cell, n)];
        if (v != 0 && v != own) candidates.add(v);
      }
    }
    int? best;
    double bestCost = double.infinity;
    for (final int color in candidates.toList()..sort()) {
      double cost = 0;
      if (costs != null) {
        for (final int cell in component) {
          cost += costs.at(cell, color - 1);
        }
      } else {
        cost = deltaE2000(paletteLab[own - 1], paletteLab[color - 1]) * component.length;
      }
      if (cost < bestCost) {
        bestCost = cost;
        best = color;
      }
    }
    return best;
  }
}

/// Шаг «слияние»: два цвета с ΔE2000 меньше [maxDeltaE] сливаются, если площадь меньшего — меньше [maxArea] доли
/// непустых клеток. Меньший цвет становится большим; палитру шаг не меняет, пустые записи убирает конвейер.
final class MergeColorsStep implements PatternStep {
  const MergeColorsStep({this.maxDeltaE = 5, this.maxArea = 0.02});

  final double maxDeltaE;
  final double maxArea;

  @override
  GeneratedPattern apply(GeneratedPattern pattern, PatternStepContext context) {
    final Uint16List values = _values(pattern.grid);
    final int k = pattern.palette.length;
    final List<Lab> lab = <Lab>[for (final e in pattern.palette) Lab.fromRgb(e.rgb)];
    final List<int> area = List<int>.filled(k + 1, 0);
    int total = 0;
    for (final int v in values) {
      if (v == 0) continue;
      area[v]++;
      total++;
    }
    final List<int> into = List<int>.generate(k + 1, (i) => i);
    while (true) {
      int? from;
      int? to;
      double best = maxDeltaE;
      for (int a = 1; a <= k; a++) {
        if (area[a] == 0) continue;
        for (int b = a + 1; b <= k; b++) {
          if (area[b] == 0) continue;
          final int small = area[a] <= area[b] ? a : b;
          if (area[small] >= maxArea * total) continue;
          final double d = deltaE2000(lab[a - 1], lab[b - 1]);
          if (d < best) {
            best = d;
            from = small;
            to = small == a ? b : a;
          }
        }
      }
      if (from == null || to == null) break;
      area[to] += area[from];
      area[from] = 0;
      for (int i = 1; i <= k; i++) {
        if (into[i] == from) into[i] = to;
      }
    }
    final Uint16List out = Uint16List(values.length);
    for (int i = 0; i < values.length; i++) {
      out[i] = values[i] == 0 ? 0 : into[values[i]];
    }
    return GeneratedPattern(grid: _grid(pattern.grid, out), palette: pattern.palette, stats: pattern.stats);
  }
}

Uint16List _values(Grid grid) {
  final Uint16List out = Uint16List(grid.width * grid.height);
  for (int row = 0; row < grid.height; row++) {
    for (int column = 0; column < grid.width; column++) {
      out[row * grid.width + column] = grid.at(column, row);
    }
  }
  return out;
}

Grid _grid(Grid like, Uint16List values) =>
    Grid.fromCells(width: like.width, height: like.height, cells: values.toList());

void _collect(Uint16List values, CellNeighbors neighbors, int start, Uint8List seen, List<int> component) {
  component
    ..clear()
    ..add(start);
  seen[start] = 1;
  for (int head = 0; head < component.length; head++) {
    final int cell = component[head];
    for (int n = 0; n < neighbors.count(cell); n++) {
      final int other = neighbors.at(cell, n);
      if (seen[other] == 0 && values[other] == values[start]) {
        seen[other] = 1;
        component.add(other);
      }
    }
  }
}

/// Тонкая линия: цепочка от трёх клеток, где у каждой клетки не больше двух соседей своего цвета и связей ровно
/// на одну меньше клеток (нет петель и «толстых» мест). Подходит и пейоту со сдвигом рядов.
bool _isThinLine(List<int> component, Uint16List values, CellNeighbors neighbors) {
  if (component.length < 3) return false;
  int links = 0;
  for (final int cell in component) {
    int same = 0;
    for (int n = 0; n < neighbors.count(cell); n++) {
      if (values[neighbors.at(cell, n)] == values[cell]) same++;
    }
    if (same > 2) return false;
    links += same;
  }
  return links ~/ 2 == component.length - 1;
}
