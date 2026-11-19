import 'dart:math' as math;

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/blend_suggester.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

double _dist(Lab x, Lab y) =>
    math.sqrt(math.pow(x.l - y.l, 2) + math.pow(x.a - y.a, 2) + math.pow(x.b - y.b, 2).toDouble());

/// Прямой перебор без кубиков Lab и без границ жадного отбора (как было до T99): образец для сверки.
List<BlendSuggestion> _reference(
  GeneratedPattern pattern,
  List<Rgb?> cellColors, {
  int? maxSuggestions,
  int minCells = 6,
  double maxPairChroma = 30,
  double maxPairLightness = 40,
  double margin = 1.5,
  double minGain = 2,
}) {
  final int count = pattern.palette.length;
  final int limit = maxSuggestions ?? math.max(4, count ~/ 4);
  final List<Lab> palette = <Lab>[for (final e in pattern.palette) Lab.fromRgb(e.rgb)];
  final List<(int, int, Rgb, Lab)> pairs = <(int, int, Rgb, Lab)>[];
  for (int i = 0; i < count; i++) {
    for (int j = i + 1; j < count; j++) {
      final double chroma = math.sqrt(
        math.pow(palette[i].a - palette[j].a, 2) + math.pow(palette[i].b - palette[j].b, 2),
      );
      if (_dist(palette[i], palette[j]) < 3 ||
          chroma > maxPairChroma ||
          (palette[i].l - palette[j].l).abs() > maxPairLightness) {
        continue;
      }
      final Rgb mix = Rgb.average(<Rgb>[pattern.palette[i].rgb, pattern.palette[j].rgb]);
      pairs.add((i, j, mix, Lab.fromRgb(mix)));
    }
  }
  final List<Map<int, double>> candidates = <Map<int, double>>[for (final _ in pairs) <int, double>{}];
  for (int cell = 0; cell < cellColors.length; cell++) {
    final Rgb? color = cellColors[cell];
    if (color == null || pattern.grid.cells[cell] == 0) continue;
    final Lab target = Lab.fromRgb(color);
    double best = double.infinity;
    int bestIndex = 0;
    for (int c = 0; c < count; c++) {
      final double d = _dist(target, palette[c]);
      if (d < best) {
        best = d;
        bestIndex = c;
      }
    }
    if (best <= margin + 1) continue;
    final double singleDe = deltaE2000(target, palette[bestIndex]);
    for (int p = 0; p < pairs.length; p++) {
      if (_dist(target, pairs[p].$4) + margin >= best) continue;
      final double gain = singleDe - deltaE2000(target, pairs[p].$4);
      if (gain > 0) candidates[p][cell] = gain;
    }
  }
  final Set<int> taken = <int>{};
  final Set<int> used = <int>{};
  final List<BlendSuggestion> out = <BlendSuggestion>[];
  while (out.length < limit) {
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
    out.add(
      BlendSuggestion(
        first: pairs[bestPair].$1,
        second: pairs[bestPair].$2,
        rgb: pairs[bestPair].$3,
        cells: cells,
        meanGain: cells.fold<double>(0, (sum, c) => sum + candidates[bestPair][c]!) / cells.length,
      ),
    );
  }
  return out;
}

void main() {
  test('предложения те же, что у прямого перебора, на случайных схемах', () {
    int totalSuggestions = 0;
    for (int seed = 0; seed < 12; seed++) {
      final math.Random random = math.Random(seed);
      final int colors = 6 + random.nextInt(30);
      // Цвета палитры кучкуются вокруг нескольких оттенков, чтобы было из чего собирать пары.
      final List<Rgb> palette = <Rgb>[
        for (int i = 0; i < colors; i++)
          Rgb(
            (60 + (i % 5) * 35 + random.nextInt(30)).clamp(0, 255),
            (40 + (i % 3) * 60 + random.nextInt(30)).clamp(0, 255),
            (50 + (i % 4) * 40 + random.nextInt(30)).clamp(0, 255),
          ),
      ];
      const int width = 70;
      const int height = 60;
      final List<int> cells = <int>[
        for (int i = 0; i < width * height; i++) random.nextInt(12) == 0 ? 0 : 1 + random.nextInt(colors),
      ];
      final List<Rgb?> photo = <Rgb?>[
        for (int i = 0; i < width * height; i++)
          if (random.nextInt(25) == 0)
            null
          else
            Rgb.average(<Rgb>[palette[random.nextInt(colors)], palette[random.nextInt(colors)]]),
      ];
      final GeneratedPattern pattern = GeneratedPattern(
        grid: Grid.fromCells(width: width, height: height, cells: cells),
        palette: <PaletteEntry>[for (final Rgb c in palette) PaletteEntry(rgb: c)],
      );
      final List<BlendSuggestion> expected = _reference(pattern, photo, maxPairChroma: 60, maxPairLightness: 80);
      final List<BlendSuggestion> actual = suggestBlends(pattern, photo, maxPairChroma: 60, maxPairLightness: 80);
      expect(actual, expected, reason: 'seed $seed');
      totalSuggestions += expected.length;
    }
    expect(totalSuggestions, greaterThan(10), reason: 'тест должен проверять не пустые ответы');
  });
}
