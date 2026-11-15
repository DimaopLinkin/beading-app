import 'dart:math' as math;

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/blend_suggester.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

GeneratedPattern _pattern(List<Rgb> palette, List<int> cells, int columns) => GeneratedPattern(
  grid: Grid.fromCells(width: columns, height: cells.length ~/ columns, cells: cells),
  palette: <PaletteEntry>[for (final Rgb c in palette) PaletteEntry(rgb: c)],
);

void main() {
  const Rgb red = Rgb(200, 40, 40);
  const Rgb yellow = Rgb(230, 200, 50);
  final Rgb orange = Rgb.average(const <Rgb>[red, yellow]);

  test('область цвета «посередине» двух ниток получает предложение бленда', () {
    final GeneratedPattern pattern = _pattern(
      const <Rgb>[red, yellow],
      <int>[for (int i = 0; i < 40; i++) i < 20 ? 1 : 2],
      10,
    );
    final List<Rgb?> photo = <Rgb?>[for (int i = 0; i < 40; i++) i < 12 ? red : (i < 28 ? orange : yellow)];
    final List<BlendSuggestion> suggestions = suggestBlends(pattern, photo, maxPairDeltaE: 120);
    expect(suggestions, hasLength(1));
    final BlendSuggestion blend = suggestions.single;
    expect((blend.first, blend.second), (0, 1));
    expect(blend.rgb, Rgb.average(const <Rgb>[red, yellow]));
    expect(blend.cells, <int>[for (int i = 12; i < 28; i++) i]);
    expect(blend.meanGain, greaterThan(2));
  });

  test('если каждая клетка совпала с цветом палитры, предложений нет', () {
    final GeneratedPattern pattern = _pattern(
      const <Rgb>[red, yellow],
      <int>[for (int i = 0; i < 40; i++) i < 20 ? 1 : 2],
      10,
    );
    final List<Rgb?> photo = <Rgb?>[for (int i = 0; i < 40; i++) i < 20 ? red : yellow];
    expect(suggestBlends(pattern, photo), isEmpty);
  });

  test('мало клеток (меньше порога) и слишком далёкие цвета — не бленд', () {
    final GeneratedPattern pattern = _pattern(
      const <Rgb>[red, yellow],
      <int>[for (int i = 0; i < 40; i++) i < 20 ? 1 : 2],
      10,
    );
    final List<Rgb?> few = <Rgb?>[for (int i = 0; i < 40; i++) i < 3 ? orange : (i < 20 ? red : yellow)];
    expect(suggestBlends(pattern, few), isEmpty);
    final List<Rgb?> photo = <Rgb?>[for (int i = 0; i < 40; i++) i < 12 ? red : (i < 28 ? orange : yellow)];
    expect(suggestBlends(pattern, photo, maxPairDeltaE: 10), isEmpty);
  });

  test('одна клетка достаётся одному предложению; не больше maxSuggestions', () {
    const Rgb blue = Rgb(40, 60, 200);
    final Rgb teal = Rgb.average(const <Rgb>[blue, yellow]);
    final GeneratedPattern pattern = _pattern(
      const <Rgb>[red, yellow, blue],
      <int>[for (int i = 0; i < 60; i++) i < 20 ? 1 : (i < 40 ? 2 : 3)],
      10,
    );
    final List<Rgb?> photo = <Rgb?>[
      for (int i = 0; i < 60; i++) i < 15 ? orange : (i < 30 ? yellow : (i < 45 ? teal : blue)),
    ];
    final List<BlendSuggestion> all = suggestBlends(pattern, photo, maxPairDeltaE: 120);
    final List<int> cells = <int>[for (final BlendSuggestion s in all) ...s.cells];
    expect(cells.length, cells.toSet().length);
    expect(suggestBlends(pattern, photo, maxPairDeltaE: 120, maxSuggestions: 1), hasLength(1));
  });

  test('быстрый поиск по светлоте даёт то же, что полный перебор пар (T70)', () {
    final math.Random random = math.Random(3);
    final List<Rgb> palette = <Rgb>[
      for (int i = 0; i < 40; i++) Rgb(random.nextInt(256), random.nextInt(256), random.nextInt(256)),
    ];
    const int columns = 60;
    final List<int> cells = <int>[for (int i = 0; i < columns * 50; i++) 1 + random.nextInt(palette.length)];
    final List<Rgb?> photo = <Rgb?>[
      for (int i = 0; i < cells.length; i++)
        i % 97 == 0 ? null : Rgb(random.nextInt(256), random.nextInt(256), random.nextInt(256)),
    ];
    final GeneratedPattern pattern = _pattern(palette, cells, columns);
    final List<BlendSuggestion> fast = suggestBlends(pattern, photo, maxSuggestions: 10, minCells: 2);
    expect(fast, isNotEmpty);
    expect(fast, _bruteForceBlends(pattern, photo, maxSuggestions: 10, minCells: 2));
  });
}

/// Прежняя реализация (перебор всех пар для каждой клетки): эталон для проверки быстрого поиска.
List<BlendSuggestion> _bruteForceBlends(
  GeneratedPattern pattern,
  List<Rgb?> cellColors, {
  int maxSuggestions = 4,
  int minCells = 6,
  double maxPairDeltaE = 30,
  double margin = 1.5,
  double minGain = 2,
}) {
  final int count = pattern.palette.length;
  if (count < 2 || cellColors.length != pattern.grid.width * pattern.grid.height) return const <BlendSuggestion>[];
  final List<Lab> palette = <Lab>[for (final e in pattern.palette) Lab.fromRgb(e.rgb)];
  final List<(int, int, Rgb, Lab)> pairs = <(int, int, Rgb, Lab)>[];
  for (int i = 0; i < count; i++) {
    for (int j = i + 1; j < count; j++) {
      final double d = _d76(palette[i], palette[j]);
      if (d < 3 || d > maxPairDeltaE) continue;
      final Rgb mix = Rgb.average(<Rgb>[pattern.palette[i].rgb, pattern.palette[j].rgb]);
      pairs.add((i, j, mix, Lab.fromRgb(mix)));
    }
  }
  if (pairs.isEmpty) return const <BlendSuggestion>[];

  // Для каждой клетки: цвет и ΔE76 до лучшего одиночного цвета.
  final List<Lab?> targets = <Lab?>[for (final Rgb? c in cellColors) c == null ? null : Lab.fromRgb(c)];
  final List<double> single = List<double>.filled(targets.length, 0);
  final List<double> singleDe = List<double>.filled(targets.length, 0);
  for (int cell = 0; cell < targets.length; cell++) {
    final Lab? target = targets[cell];
    if (target == null || pattern.grid.cells[cell] == 0) continue;
    double best = double.infinity;
    int bestIndex = 0;
    for (int c = 0; c < count; c++) {
      final double d = _d76(target, palette[c]);
      if (d < best) {
        best = d;
        bestIndex = c;
      }
    }
    single[cell] = best;
    singleDe[cell] = deltaE2000(target, palette[bestIndex]);
  }

  // Кандидаты пары: клетка и выигрыш по ΔE2000.
  final List<Map<int, double>> candidates = <Map<int, double>>[];
  for (final (int, int, Rgb, Lab) pair in pairs) {
    final Map<int, double> cells = <int, double>{};
    for (int cell = 0; cell < targets.length; cell++) {
      final Lab? target = targets[cell];
      // Клетка, уже совпавшая с цветом палитры, в бленде не нуждается.
      if (target == null || single[cell] <= margin + 1) continue;
      if (_d76(target, pair.$4) + margin >= single[cell]) continue;
      final double gain = singleDe[cell] - deltaE2000(target, pair.$4);
      if (gain > 0) cells[cell] = gain;
    }
    candidates.add(cells);
  }

  final Set<int> taken = <int>{};
  final List<BlendSuggestion> out = <BlendSuggestion>[];
  final Set<int> used = <int>{};
  while (out.length < maxSuggestions) {
    int bestPair = -1;
    double bestTotal = 0;
    for (int p = 0; p < pairs.length; p++) {
      if (used.contains(p)) continue;
      double total = 0;
      int cells = 0;
      for (final MapEntry<int, double> e in candidates[p].entries) {
        if (taken.contains(e.key)) continue;
        total += e.value;
        cells++;
      }
      if (cells < minCells || total / cells < minGain) continue;
      if (total > bestTotal) {
        bestTotal = total;
        bestPair = p;
      }
    }
    if (bestPair < 0) break;
    used.add(bestPair);
    final List<int> cells = <int>[
      for (final int cell in candidates[bestPair].keys)
        if (!taken.contains(cell)) cell,
    ]..sort();
    taken.addAll(cells);
    final (int first, int second, Rgb mix, Lab _) = pairs[bestPair];
    out.add(
      BlendSuggestion(
        first: first,
        second: second,
        rgb: mix,
        cells: cells,
        meanGain: cells.fold<double>(0, (sum, c) => sum + candidates[bestPair][c]!) / cells.length,
      ),
    );
  }
  return out;
}

double _d76(Lab x, Lab y) {
  final double dl = x.l - y.l;
  final double da = x.a - y.a;
  final double db = x.b - y.b;
  return math.sqrt(dl * dl + da * da + db * db);
}
