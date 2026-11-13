import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';

/// Контуры-бэкстич из картинки (T49, A10-1, только вышивка): шаг 7 конвейера ([cross-stitch.md]).
///
/// Бэкстич подчёркивает **детали**: глаза, брови, рот, усы, границы тёмных пятен, а не силуэт всей картинки.
/// Линия идёт по границам клеток квадратной сетки. Кандидаты — границы соседних клеток с разными цветами крестиков, где
///  - средние цвета рабочего изображения ([WorkImage]) отличаются на ΔE2000 не меньше [contrast] (слабые, от
///    [contrast] × [weakRatio], подбираются только как продолжение сильных на [hysteresis] шагов, чтобы контур не рвался);
///  - тёмная сторона границы не светлее [darkLimit]: тёмная нитка по границе двух светлых цветов выглядит грязью.
///
/// Клетки черт лица (глаза, брови, губы, нос) обводятся и при мягком контрасте: [featureBoost] усиливает контраст границы,
/// а ограничение [darkLimit] для них мягче (на 18).
///
/// Маска объекта только расставляет приоритеты: граница маски сама по себе, без контраста, не обводится, а границы вне
/// объекта весят меньше ([outsideWeight]).
///
/// Из кандидатов собираются цепочки через узлы с двумя связями; короче [minLength] клеток отбрасываются. Дальше цепочки
/// ранжируются (средний контраст × √длины, внутри объекта выше) и берутся, пока длина ниток не дойдёт до бюджета:
/// [budget] × число закрашенных клеток, но не меньше [minBudget] клеток; цепочка, которая не влезает в остаток бюджета, пропускается. Остальное упрощается Рамером — Дугласом — Пекером
/// до [tolerance] клеток, а стежок не длиннее [maxStitch] клеток. Все концы лежат на углах клеток полушаговой решётки.
///
/// Чистая функция без случайности: один вход — один результат.
final class OutlineBackstitch {
  const OutlineBackstitch({
    this.contrast = 22,
    this.minLength = 4,
    this.tolerance = 0.75,
    this.maxStitch = 6,
    this.weakRatio = 0.5,
    this.hysteresis = 2,
    this.darkLimit = 62,
    this.outsideWeight = 0.75,
    this.budget = 0.07,
    this.minBudget = 24,
    this.featureBoost = 2,
  }) : assert(contrast > 0, 'порог контраста положителен'),
       assert(minLength >= 1, 'минимум одна клетка'),
       assert(tolerance >= 0, 'допуск неотрицателен'),
       assert(maxStitch >= 1, 'стежок не короче клетки'),
       assert(weakRatio > 0 && weakRatio <= 1, 'слабый порог — доля сильного'),
       assert(hysteresis >= 0, 'шагов продолжения не меньше нуля'),
       assert(outsideWeight > 0 && outsideWeight <= 1, 'вес вне объекта — от 0 до 1'),
       assert(budget > 0, 'бюджет положителен'),
       assert(minBudget >= 0, 'минимальный бюджет неотрицателен'),
       assert(featureBoost >= 1, 'усиление черт не ослабляет');

  /// Порог контраста ΔE2000 между средними цветами соседних клеток для «сильной» границы.
  final double contrast;

  /// Цепочки короче (в длинах клетки по границам) не рисуются.
  final int minLength;

  /// Допуск упрощения линии, в клетках.
  final double tolerance;

  /// Наибольшая длина одного стежка, в клетках.
  final double maxStitch;

  /// Слабая граница (от [contrast] × [weakRatio]) берётся, если продолжает сильную.
  final double weakRatio;

  /// На сколько отрезков слабая граница может отходить от сильной.
  final int hysteresis;

  /// Тёмная сторона границы светлее этого (L, 0–100) — границу не обводим.
  final double darkLimit;

  /// Во сколько раз границы, где хотя бы одна клетка вне маски объекта, слабее внутренних (если маска есть).
  final double outsideWeight;

  /// Бюджет ниток: клеток линии на одну закрашенную клетку.
  final double budget;

  /// Бюджет не меньше этого числа клеток (для маленьких схем).
  final double minBudget;

  /// Во сколько раз контраст границ у черт лица ([build]`.features`) считается сильнее; светлая сторона им не мешает.
  final double featureBoost;

  /// Линии контуров цвета [color] (значение сетки, от 1). [subject] — маска объекта по клеткам (`1` — объект, как в
  /// T55) или `null`; [features] — клетки черт лица (`1`) или `null`; [work] и [regions] описывают ту же схему: [regions.columns] и [regions.rows] равны размеру [grid].
  List<LineStitch> build({
    required Grid grid,
    required WorkImage work,
    required CellRegions regions,
    required int color,
    Uint8List? subject,
    Uint8List? features,
  }) {
    final int columns = grid.width;
    final int rows = grid.height;
    if (regions.columns != columns || regions.rows != rows) {
      throw ArgumentError('регионы ${regions.columns}×${regions.rows} не совпадают с сеткой $columns×$rows');
    }
    if (subject != null && subject.length != columns * rows) {
      throw ArgumentError.value(subject.length, 'subject', 'ожидалось ${columns * rows} значений');
    }
    if (features != null && features.length != columns * rows) {
      throw ArgumentError.value(features.length, 'features', 'ожидалось ${columns * rows} значений');
    }
    final List<Lab?> means = _cellMeans(work, regions);
    final int stride = columns + 1;
    int node(int x, int y) => y * stride + x;
    int edgeKey(int p, int q) => p < q ? p * stride * (rows + 1) + q : q * stride * (rows + 1) + p;

    /// Вес границы между клетками [a] и [b]: контраст цветов, 0 — не кандидат.
    double strength(int a, int b) {
      final int ga = grid.cells[a];
      final int gb = grid.cells[b];
      if (ga == 0 || gb == 0 || ga == gb) return 0;
      final Lab? la = means[a];
      final Lab? lb = means[b];
      if (la == null || lb == null) return 0;
      final bool feature = features != null && (features[a] != 0 || features[b] != 0);
      if (math.min(la.l, lb.l) > darkLimit + (feature ? 18 : 0)) return 0;
      double d = deltaE2000(la, lb);
      if (feature) d *= featureBoost;
      if (subject != null && (subject[a] == 0 || subject[b] == 0)) d *= outsideWeight;
      return d;
    }

    // Отрезки по границам клеток между узлами-углами `(x, y)`, 0 ≤ x ≤ columns, 0 ≤ y ≤ rows (в клетках).
    final Map<int, double> edgeStrength = <int, double>{};
    final Map<int, (int, int)> edgeNodes = <int, (int, int)>{};
    void addEdge(int p, int q, double s) {
      if (s < contrast * weakRatio) return;
      final int key = edgeKey(p, q);
      edgeStrength[key] = s;
      edgeNodes[key] = (p, q);
    }

    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < columns; column++) {
        final int cell = row * columns + column;
        // Граница справа от клетки: вертикальный отрезок от (column + 1, row) до (column + 1, row + 1).
        if (column + 1 < columns) {
          addEdge(node(column + 1, row), node(column + 1, row + 1), strength(cell, cell + 1));
        }
        // Граница снизу: горизонтальный отрезок от (column, row + 1) до (column + 1, row + 1).
        if (row + 1 < rows) addEdge(node(column, row + 1), node(column + 1, row + 1), strength(cell, cell + columns));
      }
    }

    // Гистерезис: сильные отрезки и слабые, до которых от сильных не дальше [hysteresis] шагов.
    final Set<int> chosen = <int>{
      for (final MapEntry<int, double> e in edgeStrength.entries)
        if (e.value >= contrast) e.key,
    };
    final Set<int> reached = <int>{
      for (final int key in chosen) ...<int>[edgeNodes[key]!.$1, edgeNodes[key]!.$2],
    };
    for (int step = 0; step < hysteresis; step++) {
      final Set<int> next = <int>{};
      for (final int key in edgeStrength.keys) {
        if (chosen.contains(key)) continue;
        final (int, int) ends = edgeNodes[key]!;
        if (reached.contains(ends.$1) || reached.contains(ends.$2)) {
          chosen.add(key);
          next
            ..add(ends.$1)
            ..add(ends.$2);
        }
      }
      reached.addAll(next);
    }

    final Map<int, Set<int>> links = <int, Set<int>>{};
    void link(int p, int q) {
      (links[p] ??= <int>{}).add(q);
      (links[q] ??= <int>{}).add(p);
    }

    for (final int key in chosen) {
      link(edgeNodes[key]!.$1, edgeNodes[key]!.$2);
    }

    // Узлы у черт лица: короткие обводки глаз и бровей не отбрасываются как обрывки (от двух клеток).
    final Set<int> featureNodes = <int>{};
    if (features != null) {
      for (int cell = 0; cell < features.length; cell++) {
        if (features[cell] == 0) continue;
        final int x = cell % columns;
        final int y = cell ~/ columns;
        featureNodes.addAll(<int>[node(x, y), node(x + 1, y), node(x, y + 1), node(x + 1, y + 1)]);
      }
    }
    final List<List<int>> chains = <List<int>>[
      for (final List<int> chain in _chains(links))
        if (chain.length - 1 >= minLength || (chain.length - 1 >= 3 && chain.every(featureNodes.contains))) chain,
    ];
    // Ранг цепочки: средний контраст × √длины; сильнейшие и длиннейшие первыми, при равенстве — по порядку (детерминизм).
    double score(List<int> chain) {
      double sum = 0;
      for (int i = 0; i + 1 < chain.length; i++) {
        sum += edgeStrength[edgeKey(chain[i], chain[i + 1])] ?? 0;
      }
      final int n = chain.length - 1;
      return sum / n * math.sqrt(n);
    }

    final List<(double, int)> ranked = <(double, int)>[
      for (int i = 0; i < chains.length; i++) (score(chains[i]), i),
    ]..sort((a, b) => b.$1 != a.$1 ? b.$1.compareTo(a.$1) : a.$2.compareTo(b.$2));
    final int filled = grid.cells.where((v) => v != 0).length;
    final double limit = math.max(minBudget, budget * filled);
    double used = 0;
    final List<LineStitch> lines = <LineStitch>[];
    for (final (double, int) entry in ranked) {
      final List<int> chain = chains[entry.$2];
      // Цепочка, которая не влезает в остаток бюджета, пропускается (возможно, влезет более короткая).
      // Исключение — первая цепочка до двух бюджетов: замкнутый контур единственной детали (глаз, пятно) не пропадает.
      final double room = used == 0 ? limit * 2 : limit;
      if (used + chain.length - 1 > room) continue;
      used += chain.length - 1;
      final List<(int, int)> points = <(int, int)>[
        for (final int n in chain) (n % stride, n ~/ stride),
      ];
      final List<(int, int)> kept = _simplify(points);
      for (int i = 0; i + 1 < kept.length; i++) {
        lines.add(
          LineStitch(
            a: LatticeNode.corner(kept[i].$1, kept[i].$2),
            b: LatticeNode.corner(kept[i + 1].$1, kept[i + 1].$2),
            kind: LineKind.backstitch,
            color: color,
          ),
        );
      }
    }
    // Один и тот же отрезок могли дать две цепочки (например, после упрощения): оставляем один.
    final Map<(LatticeNode, LatticeNode), LineStitch> unique = <(LatticeNode, LatticeNode), LineStitch>{
      for (final LineStitch l in lines) l.key: l,
    };
    return unique.values.toList()..sort();
  }

  /// Самый тёмный из цветов, которые есть в сетке: цвет для контура; `null`, если сетка пуста.
  static int? darkestUsedColor(Grid grid, List<PaletteEntry> palette) {
    final Set<int> used = <int>{
      for (final int v in grid.cells)
        if (v != 0) v,
    };
    int? best;
    double bestL = double.infinity;
    for (final int v in used.toList()..sort()) {
      if (v > palette.length) continue;
      final double l = Lab.fromRgb(palette[v - 1].rgb).l;
      if (l < bestL) {
        bestL = l;
        best = v;
      }
    }
    return best;
  }

  static List<Lab?> _cellMeans(WorkImage work, CellRegions regions) {
    final List<Lab?> out = List<Lab?>.filled(regions.columns * regions.rows, null);
    for (int cell = 0; cell < out.length; cell++) {
      double l = 0;
      double a = 0;
      double b = 0;
      double weight = 0;
      for (int y = regions.top(cell); y < regions.bottom(cell); y++) {
        for (int x = regions.left(cell); x < regions.right(cell); x++) {
          final int i = y * work.width + x;
          final double w = work.alpha[i];
          l += work.lightness[i] * w;
          a += work.a[i] * w;
          b += work.b[i] * w;
          weight += w;
        }
      }
      if (weight > 0) out[cell] = Lab(l / weight, a / weight, b / weight);
    }
    return out;
  }

  /// Разбирает граф отрезков на цепочки узлов: ломаные между концами и развилками, замкнутые контуры — кольцами.
  static List<List<int>> _chains(Map<int, Set<int>> links) {
    final Set<(int, int)> seen = <(int, int)>{};
    (int, int) edge(int p, int q) => p < q ? (p, q) : (q, p);
    final List<List<int>> out = <List<int>>[];

    List<int> walk(int start, int first) {
      final List<int> chain = <int>[start, first];
      seen.add(edge(start, first));
      int previous = start;
      int current = first;
      while (links[current]!.length == 2) {
        final int next = links[current]!.firstWhere((n) => n != previous);
        if (seen.contains(edge(current, next))) break;
        seen.add(edge(current, next));
        chain.add(next);
        previous = current;
        current = next;
      }
      return chain;
    }

    final List<int> keys = links.keys.toList()..sort();
    // Сначала от концов и развилок, потом остаются только замкнутые контуры.
    for (final int n in keys) {
      if (links[n]!.length == 2) continue;
      for (final int m in links[n]!.toList()..sort()) {
        if (!seen.contains(edge(n, m))) out.add(walk(n, m));
      }
    }
    for (final int n in keys) {
      for (final int m in links[n]!.toList()..sort()) {
        if (!seen.contains(edge(n, m))) out.add(walk(n, m));
      }
    }
    return out;
  }

  /// Рамер — Дуглас — Пекер по узлам цепочки; участок делится и когда стежок получился бы длиннее [maxStitch].
  List<(int, int)> _simplify(List<(int, int)> points) {
    final List<bool> keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;
    void recurse(int from, int to) {
      if (to - from < 2) return;
      final (int, int) a = points[from];
      final (int, int) b = points[to];
      final double chord = math.sqrt(math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2));
      double far = -1;
      int at = from + 1;
      for (int i = from + 1; i < to; i++) {
        final double d = _distanceToLine(points[i], a, b);
        if (d > far + 1e-9) {
          far = d;
          at = i;
        }
      }
      if (far <= tolerance && chord <= maxStitch) return;
      // Прямой отрезок без отклонения, но слишком длинный: делим посередине.
      if (far <= tolerance) at = (from + to) ~/ 2;
      keep[at] = true;
      recurse(from, at);
      recurse(at, to);
    }

    recurse(0, points.length - 1);
    return <(int, int)>[
      for (int i = 0; i < points.length; i++)
        if (keep[i]) points[i],
    ];
  }

  static double _distanceToLine((int, int) p, (int, int) a, (int, int) b) {
    final double dx = (b.$1 - a.$1).toDouble();
    final double dy = (b.$2 - a.$2).toDouble();
    final double length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) return math.sqrt(math.pow(p.$1 - a.$1, 2) + math.pow(p.$2 - a.$2, 2));
    return ((p.$1 - a.$1) * dy - (p.$2 - a.$2) * dx).abs() / length;
  }
}
