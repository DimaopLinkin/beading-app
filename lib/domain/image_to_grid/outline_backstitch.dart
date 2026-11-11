import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';

/// Контуры-бэкстич из картинки (T49, только вышивка): шаг 7 конвейера ([cross-stitch.md]).
///
/// Линия идёт по границам клеток квадратной сетки, а не по всем границам цветов: берутся
///  - граница маски объекта (клетка объекта рядом с клеткой фона), если маска есть;
///  - границы с большим контрастом: средние цвета рабочего изображения ([WorkImage]) под соседними клетками
///    отличаются больше [contrast] (ΔE2000), а цвета крестиков в сетке разные.
///
/// Из выбранных отрезков собираются цепочки через узлы с двумя связями; цепочки короче [minLength] клеток
/// отбрасываются (обрывки), остальные упрощаются Рамером — Дугласом — Пекером до [tolerance] клеток, а стежок
/// не длиннее [maxStitch] клеток. Все концы лежат на углах клеток полушаговой решётки.
///
/// Чистая функция без случайности: один вход — один результат.
final class OutlineBackstitch {
  const OutlineBackstitch({this.contrast = 25, this.minLength = 4, this.tolerance = 0.75, this.maxStitch = 6})
    : assert(contrast > 0, 'порог контраста положителен'),
      assert(minLength >= 1, 'минимум одна клетка'),
      assert(tolerance >= 0, 'допуск неотрицателен'),
      assert(maxStitch >= 1, 'стежок не короче клетки');

  /// Порог контраста ΔE2000 между средними цветами соседних клеток.
  final double contrast;

  /// Цепочки короче (в длинах клетки по границам) не рисуются.
  final int minLength;

  /// Допуск упрощения линии, в клетках.
  final double tolerance;

  /// Наибольшая длина одного стежка, в клетках.
  final double maxStitch;

  /// Линии контуров цвета [color] (значение сетки, от 1). [subject] — маска объекта по клеткам (`1` — объект, как в
  /// T55) или `null`; [work] и [regions] описывают ту же схему: [regions.columns] и [regions.rows] равны размеру [grid].
  List<LineStitch> build({
    required Grid grid,
    required WorkImage work,
    required CellRegions regions,
    required int color,
    Uint8List? subject,
  }) {
    final int columns = grid.width;
    final int rows = grid.height;
    if (regions.columns != columns || regions.rows != rows) {
      throw ArgumentError('регионы ${regions.columns}×${regions.rows} не совпадают с сеткой $columns×$rows');
    }
    if (subject != null && subject.length != columns * rows) {
      throw ArgumentError.value(subject.length, 'subject', 'ожидалось ${columns * rows} значений');
    }
    final List<Lab?> means = _cellMeans(work, regions);
    bool selected(int a, int b) {
      if (subject != null && (subject[a] == 0) != (subject[b] == 0)) return true;
      final int ga = grid.cells[a];
      final int gb = grid.cells[b];
      if (ga == 0 || gb == 0 || ga == gb) return false;
      final Lab? la = means[a];
      final Lab? lb = means[b];
      return la != null && lb != null && deltaE2000(la, lb) >= contrast;
    }

    // Отрезки по границам клеток между узлами-углами `(x, y)`, 0 ≤ x ≤ columns, 0 ≤ y ≤ rows (в клетках).
    final Map<int, Set<int>> links = <int, Set<int>>{};
    int node(int x, int y) => y * (columns + 1) + x;
    void link(int p, int q) {
      (links[p] ??= <int>{}).add(q);
      (links[q] ??= <int>{}).add(p);
    }

    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < columns; column++) {
        final int cell = row * columns + column;
        // Граница справа от клетки: вертикальный отрезок от (column + 1, row) до (column + 1, row + 1).
        if (column + 1 < columns && selected(cell, cell + 1)) link(node(column + 1, row), node(column + 1, row + 1));
        // Граница снизу: горизонтальный отрезок от (column, row + 1) до (column + 1, row + 1).
        if (row + 1 < rows && selected(cell, cell + columns)) link(node(column, row + 1), node(column + 1, row + 1));
      }
    }

    final List<List<int>> chains = _chains(links);
    final List<LineStitch> lines = <LineStitch>[];
    for (final List<int> chain in chains) {
      if (chain.length - 1 < minLength) continue;
      final List<(int, int)> points = <(int, int)>[
        for (final int n in chain) (n % (columns + 1), n ~/ (columns + 1)),
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
