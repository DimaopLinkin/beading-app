import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/cell_neighbors.dart';
import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/palette_constraint.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Что делать с фоном (клетками вне маски объекта), T55.
enum BackgroundMode {
  /// Как есть.
  keep,

  /// Фон получает не больше [BackgroundStage.maxBackgroundColors] цветов и сильно сглаживается.
  simplify,

  /// Клетки фона пустые: бусины там не будет.
  remove,
}

/// Маска объекта на уровне клеток: `1` — клетка объекта, `0` — фон. Клетка объект, если под ней объекта не меньше половины пикселей.
Uint8List subjectCellsFrom({
  required Uint8List mask,
  required int imageWidth,
  required CellRegions regions,
}) {
  final Uint8List out = Uint8List(regions.columns * regions.rows);
  for (int cell = 0; cell < out.length; cell++) {
    int inside = 0;
    int total = 0;
    for (int y = regions.top(cell); y < regions.bottom(cell); y++) {
      for (int x = regions.left(cell); x < regions.right(cell); x++) {
        total++;
        if (mask[y * imageWidth + x] != 0) inside++;
      }
    }
    out[cell] = total > 0 && inside * 2 >= total ? 1 : 0;
  }
  return out;
}

/// Стадия фона и контура объекта (T55). Работает по готовой схеме и маске объекта на уровне клеток.
abstract final class BackgroundStage {
  static const int maxBackgroundColors = 3;

  /// Применяет [mode] к фону и, если [outline], обводит объект одной клеткой тёмного цвета.
  static GeneratedPattern apply({
    required GeneratedPattern pattern,
    required List<Rgb?> cellColors,
    required Uint8List subject,
    required CellNeighbors neighbors,
    required BackgroundMode mode,
    required bool outline,
    required int maxColors,
    PaletteConstraint constraint = const PaletteConstraint.free(),
  }) {
    if (mode == BackgroundMode.keep && !outline) return pattern;
    final int columns = pattern.grid.width;
    final int rows = pattern.grid.height;
    final Uint16List values = Uint16List(columns * rows);
    for (int i = 0; i < values.length; i++) {
      values[i] = pattern.grid.at(i % columns, i ~/ columns);
    }
    List<PaletteEntry> palette = pattern.palette;
    switch (mode) {
      case BackgroundMode.keep:
        break;
      case BackgroundMode.remove:
        for (int i = 0; i < values.length; i++) {
          if (subject[i] == 0) values[i] = 0;
        }
      case BackgroundMode.simplify:
        _simplify(values, palette, cellColors, subject, neighbors);
    }
    if (outline) {
      palette = _outline(values, palette, cellColors, subject, neighbors, maxColors, constraint);
    }
    return GeneratedPattern(
      grid: Grid.fromCells(width: columns, height: rows, cells: values.toList()),
      palette: palette,
      stats: pattern.stats,
    );
  }

  /// Клетки объекта, у которых есть сосед-фон: ровно та обводка, что рисует [apply].
  static List<int> outlineCells(Uint8List subject, CellNeighbors neighbors) => <int>[
    for (int cell = 0; cell < subject.length; cell++)
      if (subject[cell] == 1 && _hasBackgroundNeighbor(cell, subject, neighbors)) cell,
  ];

  static bool _hasBackgroundNeighbor(int cell, Uint8List subject, CellNeighbors neighbors) {
    for (int n = 0; n < neighbors.count(cell); n++) {
      if (subject[neighbors.at(cell, n)] == 0) return true;
    }
    return false;
  }

  static void _simplify(
    Uint16List values,
    List<PaletteEntry> palette,
    List<Rgb?> cellColors,
    Uint8List subject,
    CellNeighbors neighbors,
  ) {
    final List<int> bg = <int>[
      for (int i = 0; i < values.length; i++)
        if (subject[i] == 0 && values[i] != 0) i,
    ];
    if (bg.isEmpty) return;
    final int k = palette.length;
    final List<Lab> paletteLab = <Lab>[for (final PaletteEntry e in palette) Lab.fromRgb(e.rgb)];
    // Цена цвета палитры для каждой клетки фона: ΔE2000 до среднего цвета фото под клеткой.
    final List<List<double>> cost = <List<double>>[
      for (final int cell in bg)
        <double>[
          for (int c = 0; c < k; c++)
            cellColors[cell] == null ? 0 : deltaE2000(Lab.fromRgb(cellColors[cell]!), paletteLab[c]),
        ],
    ];
    final List<double> best = List<double>.filled(bg.length, double.infinity);
    final List<int> chosen = <int>[];
    double total = double.infinity;
    while (chosen.length < maxBackgroundColors) {
      int pick = -1;
      double pickTotal = double.infinity;
      for (int c = 0; c < k; c++) {
        if (chosen.contains(c)) continue;
        double sum = 0;
        for (int i = 0; i < bg.length; i++) {
          sum += math.min(best[i], cost[i][c]);
        }
        if (sum < pickTotal) {
          pickTotal = sum;
          pick = c;
        }
      }
      if (pick < 0) break;
      // Следующий цвет берём, только если он заметно (на 15 %) снижает общую цену: иначе фон останется спокойным.
      if (chosen.isNotEmpty && pickTotal > total * 0.85) break;
      chosen.add(pick);
      total = pickTotal;
      for (int i = 0; i < bg.length; i++) {
        best[i] = math.min(best[i], cost[i][pick]);
      }
    }
    for (int i = 0; i < bg.length; i++) {
      int arg = chosen.first;
      for (final int c in chosen) {
        if (cost[i][c] < cost[i][arg]) arg = c;
      }
      values[bg[i]] = arg + 1;
    }
    // Сильное сглаживание: клетка фона переходит к цвету, которого среди соседей фона больше, чем её собственного.
    for (int pass = 0; pass < 3; pass++) {
      final Uint16List snapshot = Uint16List.fromList(values);
      for (final int cell in bg) {
        final Map<int, int> counts = <int, int>{};
        for (int n = 0; n < neighbors.count(cell); n++) {
          final int other = neighbors.at(cell, n);
          if (subject[other] == 0 && snapshot[other] != 0) counts[snapshot[other]] = (counts[snapshot[other]] ?? 0) + 1;
        }
        final int own = counts[snapshot[cell]] ?? 0;
        int top = snapshot[cell];
        int topCount = own;
        for (final int color in counts.keys.toList()..sort()) {
          if (counts[color]! > topCount) {
            top = color;
            topCount = counts[color]!;
          }
        }
        values[cell] = top;
      }
    }
  }

  /// Красит клетки обводки самым тёмным подходящим цветом; возвращает палитру (в неё мог добавиться тёмный цвет).
  static List<PaletteEntry> _outline(
    Uint16List values,
    List<PaletteEntry> palette,
    List<Rgb?> cellColors,
    Uint8List subject,
    CellNeighbors neighbors,
    int maxColors,
    PaletteConstraint constraint,
  ) {
    final List<int> border = <int>[
      for (final int cell in outlineCells(subject, neighbors))
        if (values[cell] != 0) cell,
    ];
    if (border.isEmpty) return palette;
    final List<PaletteEntry> out = List<PaletteEntry>.of(palette);
    int darkest = -1;
    double darkestL = double.infinity;
    final Set<int> used = <int>{
      for (final int v in values)
        if (v != 0) v - 1,
    };
    for (final int c in used) {
      final double l = Lab.fromRgb(out[c].rgb).l;
      if (l < darkestL) {
        darkestL = l;
        darkest = c;
      }
    }
    if (darkestL > 35 && used.length < maxColors) {
      final PaletteEntry? extra = _darkEntry(border, cellColors, constraint);
      if (extra != null) {
        int index = out.indexOf(extra);
        if (index < 0 && Lab.fromRgb(extra.rgb).l < darkestL) {
          out.add(extra);
          index = out.length - 1;
        }
        if (index >= 0 && Lab.fromRgb(out[index].rgb).l < darkestL) darkest = index;
      }
    }
    if (darkest < 0) return palette;
    for (final int cell in border) {
      values[cell] = darkest + 1;
    }
    return out;
  }

  /// Тёмный цвет по тону границы: те же оттенок и половина насыщенности, светлота около 18.
  static PaletteEntry? _darkEntry(List<int> border, List<Rgb?> cellColors, PaletteConstraint constraint) {
    double a = 0;
    double b = 0;
    int n = 0;
    for (final int cell in border) {
      final Rgb? c = cellColors[cell];
      if (c == null) continue;
      final Lab lab = Lab.fromRgb(c);
      a += lab.a;
      b += lab.b;
      n++;
    }
    if (n == 0) return null;
    final Rgb target = Lab(18, a / n * 0.5, b / n * 0.5).toRgb();
    final List<PaletteEntry>? candidates = constraint.candidates;
    if (candidates == null) return PaletteEntry(rgb: target);
    return NearestColorMatcher<PaletteEntry>(candidates, rgbOf: (e) => e.rgb).nearest(target, count: 1).single.item;
  }
}
