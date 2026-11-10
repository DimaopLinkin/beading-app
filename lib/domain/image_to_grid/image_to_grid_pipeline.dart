import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/cell_sampler.dart';
import 'package:beading/domain/image_to_grid/color_assigner.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';
import 'package:beading/domain/image_to_grid/quantizer.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Конвейер «картинка → схема»: ресэмплинг → квантование → привязка к допустимым цветам → шаги (очистка, слои).
///
/// Каждый шаг — отдельная чистая функция со своими тестами; конвейер только соединяет их.
final class ImageToGridPipeline {
  const ImageToGridPipeline({
    this.sampler = const CellSampler(),
    this.quantizer = const LabQuantizer(),
    this.assigner = const ColorAssigner(),
  });

  final CellSampler sampler;
  final LabQuantizer quantizer;
  final ColorAssigner assigner;

  GeneratedPattern run(ImageToGridRequest request) {
    final SampledCells cells = sampler.sample(
      image: request.image,
      importance: request.importance,
      geometry: request.geometry,
      metrics: request.metrics,
      columns: request.columns,
      rows: request.rows,
    );
    final List<PaletteEntry> palette = _choosePalette(request, cells);
    final Uint16List values = assigner.assign(
      cells: cells.colors,
      columns: cells.columns,
      rows: cells.rows,
      palette: <Rgb>[for (final PaletteEntry e in palette) e.rgb],
      dither: request.dither,
    );
    GeneratedPattern pattern = _compact(values, palette, cells);
    final PatternStepContext context = PatternStepContext(
      geometry: request.geometry,
      cellImportance: cells.importance,
    );
    for (final PatternStep step in request.steps) {
      pattern = step.apply(pattern, context);
    }
    return pattern;
  }

  List<PaletteEntry> _choosePalette(ImageToGridRequest request, SampledCells cells) {
    final List<PaletteEntry>? candidates = request.constraint.candidates;
    if (candidates != null && candidates.length <= request.maxColors) return candidates;

    final List<Rgb> colors = <Rgb>[];
    final List<double> weights = <double>[];
    for (int i = 0; i < cells.colors.length; i++) {
      final Rgb? color = cells.colors[i];
      if (color == null) continue;
      colors.add(color);
      weights.add(cells.importance[i]);
    }
    if (colors.isEmpty) return const <PaletteEntry>[];

    final Quantization quantization = quantizer.quantize(
      <Lab>[for (final Rgb c in colors) Lab.fromRgb(c)],
      weights,
      colors: request.maxColors,
      seed: request.seed,
    );
    // Цвет кластера для показа: среднее реальных цветов ячеек (однотонная область остаётся точным цветом).
    final int clusters = quantization.centers.length;
    final List<int> sums = List<int>.filled(clusters * 3, 0);
    final List<int> counts = List<int>.filled(clusters, 0);
    for (int i = 0; i < colors.length; i++) {
      final int c = quantization.assignments[i];
      sums[c * 3] += colors[i].r;
      sums[c * 3 + 1] += colors[i].g;
      sums[c * 3 + 2] += colors[i].b;
      counts[c]++;
    }
    final List<Rgb> means = <Rgb>[
      for (int c = 0; c < clusters; c++)
        Rgb(
          (sums[c * 3] / counts[c]).round(),
          (sums[c * 3 + 1] / counts[c]).round(),
          (sums[c * 3 + 2] / counts[c]).round(),
        ),
    ];

    if (candidates == null) return <PaletteEntry>[for (final Rgb mean in means) PaletteEntry(rgb: mean)];

    // Ограничение: каждому центру — ближайшая допустимая позиция, повторы схлопываются.
    final NearestColorMatcher<PaletteEntry> matcher = NearestColorMatcher<PaletteEntry>(
      candidates,
      rgbOf: (e) => e.rgb,
    );
    final List<PaletteEntry> chosen = <PaletteEntry>[];
    for (final Rgb mean in means) {
      final PaletteEntry entry = matcher.nearest(mean, count: 1).single.item;
      if (!chosen.contains(entry)) chosen.add(entry);
    }
    return chosen;
  }

  /// Убирает цвета, которых нет в сетке, и упорядочивает палитру: чаще встречающиеся первыми.
  GeneratedPattern _compact(Uint16List values, List<PaletteEntry> palette, SampledCells cells) {
    final List<int> counts = List<int>.filled(palette.length, 0);
    for (final int v in values) {
      if (v > 0) counts[v - 1]++;
    }
    final List<int> order = <int>[
      for (int i = 0; i < palette.length; i++)
        if (counts[i] > 0) i,
    ]..sort((a, b) => counts[a] != counts[b] ? counts[b].compareTo(counts[a]) : a.compareTo(b));
    final List<int> remap = List<int>.filled(palette.length, 0);
    for (int n = 0; n < order.length; n++) {
      remap[order[n]] = n + 1;
    }
    return GeneratedPattern(
      grid: Grid.fromCells(
        width: cells.columns,
        height: cells.rows,
        cells: <int>[for (final int v in values) v == 0 ? 0 : remap[v - 1]],
      ),
      palette: <PaletteEntry>[for (final int i in order) palette[i]],
    );
  }
}
