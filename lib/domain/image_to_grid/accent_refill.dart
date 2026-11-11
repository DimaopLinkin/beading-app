import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/cell_neighbors.dart';
import 'package:beading/domain/image_to_grid/cell_sampler.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/palette_constraint.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Отдаёт цвета, освободившиеся при слиянии и очистке, следующему акценту («детально»): число цветов в настройке —
/// верхняя граница, и пока в ней есть место, самая плохо покрытая группа клеток получает свой цвет.
///
/// Группа — клетки, у которых средний цвет фото дальше [minDeltaE] (ΔE2000) от их цвета в схеме и близок друг к другу
/// (в пределах [groupDeltaE]); не меньше [minGroup] клеток, и в схеме клетка группы получает хотя бы одного соседа
/// нового цвета, иначе вышла бы «конфетти».
GeneratedPattern refillAccents({
  required GeneratedPattern pattern,
  required SampledCells cells,
  required CellNeighbors neighbors,
  required Float32List importance,
  required int maxColors,
  required PaletteConstraint constraint,
  double minDeltaE = 12,
  double groupDeltaE = 8,
  int minGroup = 3,
}) {
  final List<PaletteEntry> palette = List<PaletteEntry>.of(pattern.palette);
  final int count = cells.colors.length;
  final Uint16List values = Uint16List(count);
  for (int i = 0; i < count; i++) {
    values[i] = pattern.grid.at(i % cells.columns, i ~/ cells.columns);
  }
  final List<Lab?> source = <Lab?>[for (final Rgb? c in cells.colors) c == null ? null : Lab.fromRgb(c)];
  final List<PaletteEntry>? candidates = constraint.candidates;
  final NearestColorMatcher<PaletteEntry>? matcher = candidates == null
      ? null
      : NearestColorMatcher<PaletteEntry>(candidates, rgbOf: (e) => e.rgb);
  bool changed = false;

  // Недобор цвета по клеткам считается один раз: отвергнутый зародыш обнуляет свою клетку, принятая группа пересчитывает
  // только свои клетки, а не все (ΔE2000 по миллиону клеток на каждый зародыш был самым дорогим местом конвейера).
  final List<Lab> paletteLab = <Lab>[for (final PaletteEntry e in palette) Lab.fromRgb(e.rgb)];
  final List<double> miss = List<double>.filled(count, 0);
  for (int i = 0; i < count; i++) {
    final Lab? lab = source[i];
    if (lab == null || values[i] == 0) continue;
    miss[i] = deltaE2000(lab, paletteLab[values[i] - 1]);
  }

  while (palette.length < maxColors) {
    int seed = -1;
    double seedScore = 0;
    for (int i = 0; i < count; i++) {
      if (miss[i] < minDeltaE) continue;
      final double score = miss[i] * importance[i];
      if (score > seedScore) {
        seedScore = score;
        seed = i;
      }
    }
    if (seed < 0) break;
    final Lab seedLab = source[seed]!;
    final Set<int> group = <int>{
      for (int i = 0; i < count; i++)
        if (miss[i] >= minDeltaE && deltaE2000(seedLab, source[i]!) <= groupDeltaE) i,
    };
    // Клетки без соседа в группе дали бы одиночные: убираем, пока группа не устоится.
    bool shrunk = true;
    while (shrunk) {
      shrunk = false;
      for (final int cell in group.toList()) {
        bool linked = false;
        for (int n = 0; n < neighbors.count(cell) && !linked; n++) {
          linked = group.contains(neighbors.at(cell, n));
        }
        if (!linked) {
          group.remove(cell);
          shrunk = true;
        }
      }
    }
    if (group.length < minGroup || !group.contains(seed)) {
      miss[seed] = 0; // отвергнутый зародыш больше не рассматривается
      continue;
    }
    double l = 0;
    double a = 0;
    double b = 0;
    for (final int cell in group) {
      l += source[cell]!.l;
      a += source[cell]!.a;
      b += source[cell]!.b;
    }
    final Rgb mean = Lab(l / group.length, a / group.length, b / group.length).toRgb();
    PaletteEntry entry = PaletteEntry(rgb: mean);
    if (matcher != null) {
      final PaletteEntry? free = matcher
          .nearest(mean, count: palette.length + 1)
          .map((m) => m.item)
          .where((e) => !palette.contains(e))
          .firstOrNull;
      if (free == null) break;
      entry = free;
    }
    palette.add(entry);
    final Lab entryLab = Lab.fromRgb(entry.rgb);
    paletteLab.add(entryLab);
    for (final int cell in group) {
      values[cell] = palette.length;
      miss[cell] = deltaE2000(source[cell]!, entryLab);
    }
    changed = true;
  }
  if (!changed) return pattern;
  return GeneratedPattern(
    grid: Grid.fromCells(width: cells.columns, height: cells.rows, cells: values.toList()),
    palette: palette,
    stats: pattern.stats,
  );
}
