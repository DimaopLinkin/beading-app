import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/cell_costs.dart';
import 'package:beading/domain/image_to_grid/cell_neighbors.dart';
import 'package:beading/domain/image_to_grid/face_guide.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';
import 'package:beading/domain/palette/lab.dart';

/// Шаг «лица» (T54), после очистки: кожа лица и черты.
///
/// - Кожа: клетки кожи красятся не больше чем [maxSkinColors] цветами, выбранными по ценам цвета (набор, дающий
///   наименьшую суммарную цену), и в коже не остаётся островов меньше [minSkinIsland] клеток.
/// - Зрачки: самый тёмный из [featureCandidates] лучших для клетки цветов, линия губ: самый насыщенный из них.
///   «Лучших» ограничение нужно, чтобы чёрная точка не появилась там, где по картинке ей не место.
///
/// Если после этого в глазу нет ни одной тёмной клетки (зрачок мельче клетки и растворился в коже и белке), самая
/// подходящая клетка глаза получает самый тёмный цвет палитры, но только если он темнее [darkLightness].
///
/// Черты не перекрашиваются очисткой кожи. Без лиц, без цен цветов и на путях без разметки по пикселям шаг ничего
/// не делает.
final class FaceFeatureStep implements PatternStep {
  const FaceFeatureStep({
    this.maxSkinColors = 4,
    this.minSkinIsland = 3,
    this.featureCandidates = 3,
    this.darkLightness = 45,
  }) : assert(maxSkinColors >= 1, 'на кожу нужен хотя бы один цвет'),
       assert(minSkinIsland >= 2, 'minSkinIsland не меньше 2'),
       assert(featureCandidates >= 1, 'featureCandidates не меньше 1');

  final int maxSkinColors;
  final int minSkinIsland;
  final int featureCandidates;

  /// Цвет темнее этой светлоты (L*) считается «тёмным» для глаза.
  final double darkLightness;

  @override
  GeneratedPattern apply(GeneratedPattern pattern, PatternStepContext context) {
    final FaceCells? faces = context.faces;
    final CellCosts? costs = context.costs;
    if (faces == null || costs == null || pattern.palette.isEmpty) return pattern;
    final Grid grid = pattern.grid;
    final int columns = grid.width;
    final int rows = grid.height;
    final Uint16List values = Uint16List(columns * rows);
    for (int i = 0; i < values.length; i++) {
      values[i] = grid.at(i % columns, i ~/ columns);
    }
    final List<Lab> palette = <Lab>[for (final e in pattern.palette) Lab.fromRgb(e.rgb)];
    final CellNeighbors neighbors = CellNeighbors.of(geometry: context.geometry, columns: columns, rows: rows);

    _paintSkin(values, faces, costs, palette.length, neighbors);
    _paintFeatures(values, faces.pupils, costs, palette, (lab) => -lab.l);
    _ensureDarkEyes(values, faces, costs, palette);
    _paintFeatures(values, faces.lips, costs, palette, (lab) => lab.a * lab.a + lab.b * lab.b);
    return GeneratedPattern(
      grid: Grid.fromCells(width: columns, height: rows, cells: values.toList()),
      palette: pattern.palette,
      stats: pattern.stats,
    );
  }

  void _paintSkin(Uint16List values, FaceCells faces, CellCosts costs, int colors, CellNeighbors neighbors) {
    final List<int> cells = <int>[
      for (int i = 0; i < values.length; i++)
        if (faces.isSkin(i) && values[i] != 0) i,
    ];
    if (cells.isEmpty) return;
    final List<int> allowed = _chooseSkinColors(cells, costs, colors);
    for (final int cell in cells) {
      values[cell] = _cheapestOf(cell, allowed, costs) + 1;
    }
    // Острова внутри кожи: до трёх проходов, цвет берётся только из цветов кожи.
    final Set<int> skinSet = allowed.map((c) => c + 1).toSet();
    for (int pass = 0; pass < 3; pass++) {
      bool changed = false;
      final Uint8List seen = Uint8List(values.length);
      for (final int start in cells) {
        if (seen[start] == 1) continue;
        final List<int> component = <int>[start];
        seen[start] = 1;
        for (int head = 0; head < component.length; head++) {
          final int cell = component[head];
          for (int n = 0; n < neighbors.count(cell); n++) {
            final int other = neighbors.at(cell, n);
            if (seen[other] == 0 && values[other] == values[start] && faces.isSkin(other)) {
              seen[other] = 1;
              component.add(other);
            }
          }
        }
        if (component.length >= minSkinIsland) continue;
        final Map<int, double> score = <int, double>{};
        for (final int cell in component) {
          for (int n = 0; n < neighbors.count(cell); n++) {
            final int v = values[neighbors.at(cell, n)];
            if (v != values[start] && skinSet.contains(v)) score[v] = 0;
          }
        }
        if (score.isEmpty) continue;
        int? best;
        double bestCost = double.infinity;
        for (final int v in score.keys.toList()..sort()) {
          double cost = 0;
          for (final int cell in component) {
            cost += costs.at(cell, v - 1);
          }
          if (cost < bestCost) {
            bestCost = cost;
            best = v;
          }
        }
        for (final int cell in component) {
          values[cell] = best!;
        }
        changed = true;
      }
      if (!changed) break;
    }
  }

  /// Жадно набирает до [maxSkinColors] цветов, каждый раз беря тот, что сильнее всего снижает суммарную цену клеток кожи.
  List<int> _chooseSkinColors(List<int> cells, CellCosts costs, int colors) {
    final List<int> chosen = <int>[];
    final List<double> best = List<double>.filled(cells.length, double.infinity);
    final int limit = maxSkinColors < colors ? maxSkinColors : colors;
    while (chosen.length < limit) {
      int? pick;
      double pickTotal = double.infinity;
      for (int color = 0; color < colors; color++) {
        if (chosen.contains(color)) continue;
        double total = 0;
        for (int i = 0; i < cells.length; i++) {
          final double c = costs.at(cells[i], color);
          total += c < best[i] ? c : best[i];
        }
        if (total < pickTotal) {
          pickTotal = total;
          pick = color;
        }
      }
      if (pick == null) break;
      chosen.add(pick);
      for (int i = 0; i < cells.length; i++) {
        final double c = costs.at(cells[i], pick);
        if (c < best[i]) best[i] = c;
      }
    }
    return chosen;
  }

  int _cheapestOf(int cell, List<int> allowed, CellCosts costs) {
    int best = allowed.first;
    double bestCost = double.infinity;
    for (final int color in allowed) {
      final double c = costs.at(cell, color);
      if (c < bestCost) {
        bestCost = c;
        best = color;
      }
    }
    return best;
  }

  void _ensureDarkEyes(Uint16List values, FaceCells faces, CellCosts costs, List<Lab> palette) {
    int darkest = 0;
    for (int i = 1; i < palette.length; i++) {
      if (palette[i].l < palette[darkest].l) darkest = i;
    }
    if (palette[darkest].l >= darkLightness) return;
    for (final List<int> eye in faces.eyes) {
      final List<int> own = <int>[
        for (final int cell in eye)
          if (values[cell] != 0) cell,
      ];
      if (own.isEmpty || own.any((c) => palette[values[c] - 1].l < darkLightness)) continue;
      int best = own.first;
      for (final int cell in own) {
        if (costs.at(cell, darkest) < costs.at(best, darkest)) best = cell;
      }
      values[best] = darkest + 1;
    }
  }

  /// Для каждой клетки из [cells] берёт из [featureCandidates] лучших цветов тот, у кого [score] больше.
  void _paintFeatures(
    Uint16List values,
    List<int> cells,
    CellCosts costs,
    List<Lab> palette,
    double Function(Lab) score,
  ) {
    for (final int cell in cells) {
      if (values[cell] == 0) continue;
      final List<int> order = List<int>.generate(palette.length, (i) => i)
        ..sort((a, b) {
          final int byCost = costs.at(cell, a).compareTo(costs.at(cell, b));
          return byCost != 0 ? byCost : a.compareTo(b);
        });
      int best = order.first;
      for (final int color in order.take(featureCandidates)) {
        if (score(palette[color]) > score(palette[best])) best = color;
      }
      values[cell] = best + 1;
    }
  }
}
