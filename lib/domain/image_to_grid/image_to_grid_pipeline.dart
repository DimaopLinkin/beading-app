import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/accent_refill.dart';
import 'package:beading/domain/image_to_grid/cell_edges.dart';
import 'package:beading/domain/image_to_grid/cell_labeler.dart';
import 'package:beading/domain/image_to_grid/cell_neighbors.dart';
import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/cell_sampler.dart';
import 'package:beading/domain/image_to_grid/color_assigner.dart';
import 'package:beading/domain/image_to_grid/face_guide.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/generation_stats.dart';
import 'package:beading/domain/image_to_grid/image_prefilter.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/label_smoother.dart';
import 'package:beading/domain/image_to_grid/palette_builder.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/pattern_metrics.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';
import 'package:beading/domain/image_to_grid/quantizer.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Конвейер «картинка → схема»: подготовка фото (по желанию) → ресэмплинг → квантование → привязка к допустимым цветам → шаги (очистка, слои).
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
    final Stopwatch clock = Stopwatch()..start();
    final Map<String, Duration> times = <String, Duration>{};
    Duration lap() {
      final Duration elapsed = clock.elapsed;
      clock.reset();
      return elapsed;
    }

    if (request.usesPixelStages) return _runPixelStages(request, clock, times, lap);

    SourceImage image = request.image;
    Float32List? importance = request.importance;
    final ImagePrefilter? prefilter = request.prefilter;
    if (prefilter != null) {
      final WorkImage work = prefilter.apply(
        WorkImage.fromSource(
          image: image,
          importance: importance,
          geometry: request.geometry,
          metrics: request.metrics,
          columns: request.columns,
          rows: request.rows,
        ),
      );
      image = work.toSourceImage();
      importance = work.importance;
      times['prefilter'] = lap();
    }
    final SampledCells cells = sampler.sample(
      image: image,
      importance: importance,
      geometry: request.geometry,
      metrics: request.metrics,
      columns: request.columns,
      rows: request.rows,
    );
    times['sample'] = lap();
    final List<PaletteEntry> palette = _choosePalette(request, cells);
    times['palette'] = lap();
    final Uint16List values = assigner.assign(
      cells: cells.colors,
      columns: cells.columns,
      rows: cells.rows,
      palette: <Rgb>[for (final PaletteEntry e in palette) e.rgb],
      dither: request.dither,
    );
    GeneratedPattern pattern = _compact(values, palette, cells);
    times['assign'] = lap();
    final PatternStepContext context = PatternStepContext(
      geometry: request.geometry,
      cellImportance: cells.importance,
    );
    for (final PatternStep step in request.steps) {
      pattern = step.apply(pattern, context);
    }
    times['steps'] = lap();
    return GeneratedPattern(
      grid: pattern.grid,
      palette: pattern.palette,
      stats: _stats(pattern, cells, request.geometry, times),
    );
  }

  /// Путь по ADR-0004: рабочее изображение → палитра по пикселям → цвет клетки голосованием → шаги с ценами цветов.
  GeneratedPattern _runPixelStages(
    ImageToGridRequest request,
    Stopwatch clock,
    Map<String, Duration> times,
    Duration Function() lap,
  ) {
    WorkImage work = WorkImage.fromSource(
      image: request.image,
      importance: request.importance,
      geometry: request.geometry,
      metrics: request.metrics,
      columns: request.columns,
      rows: request.rows,
    );
    final ImagePrefilter? prefilter = request.prefilter;
    if (prefilter != null) {
      work = prefilter.apply(work);
      times['prefilter'] = lap();
    }
    // Цвета клеток нужны только для важности клеток и метрики ΔE: средние по рабочей картинке, как в пути T24.
    final SampledCells cells = sampler.sample(
      image: work.toSourceImage(),
      importance: work.importance,
      geometry: request.geometry,
      metrics: request.metrics,
      columns: request.columns,
      rows: request.rows,
    );
    final CellRegions regions = CellRegions.forGrid(
      geometry: request.geometry,
      metrics: request.metrics,
      columns: request.columns,
      rows: request.rows,
      imageWidth: work.width,
      imageHeight: work.height,
    );
    final FaceGuide? faceGuide = (request.faces?.isEmpty ?? true) ? null : request.faces;
    times['sample'] = lap();
    final List<PaletteEntry> palette = (request.paletteBuilder ?? const AccentPaletteBuilder()).build(
      PaletteRequest(
        work: work,
        maxColors: request.maxColors,
        constraint: request.constraint,
        seed: request.seed,
        regions: regions,
        skinPixels: faceGuide?.skinPixels(work.width, work.height),
      ),
    );
    times['palette'] = lap();
    final LabeledCells labeled = (request.labeler ?? const VotingCellLabeler()).label(
      work: work,
      regions: regions,
      palette: <Lab>[for (final PaletteEntry e in palette) Lab.fromRgb(e.rgb)],
    );
    final int singlesBefore = countSingleCells(
      Grid.fromCells(width: cells.columns, height: cells.rows, cells: labeled.values.toList()),
      request.geometry,
    );
    final CellNeighbors neighbors = CellNeighbors.of(
      geometry: request.geometry,
      columns: cells.columns,
      rows: cells.rows,
    );
    final Float32List edges = cellEdges(work, regions);
    final LabelSmoother? smoother = request.smoother;
    final Uint16List values = smoother == null
        ? labeled.values
        : smoother.smooth(
            values: labeled.values,
            costs: labeled.costs,
            neighbors: neighbors,
            importance: cells.importance,
            edges: edges,
          );
    final (GeneratedPattern compact, List<int> order) = _compactOrdered(values, palette, cells);
    GeneratedPattern pattern = compact;
    times['assign'] = lap();
    final PatternStepContext context = PatternStepContext(
      geometry: request.geometry,
      cellImportance: cells.importance,
      costs: labeled.costs.select(order),
      cellEdges: edges,
      faces: faceGuide?.cells(regions, workWidth: work.width, workHeight: work.height),
    );
    for (final PatternStep step in request.steps) {
      pattern = step.apply(pattern, context);
    }
    if (request.refillFreedColors) {
      // Сначала убираем опустевшие записи палитры: только так видно, сколько мест освободилось.
      pattern = _compactPattern(pattern, cells);
      pattern = refillAccents(
        pattern: pattern,
        cells: cells,
        neighbors: neighbors,
        importance: cells.importance,
        maxColors: request.maxColors,
        constraint: request.constraint,
      );
    }
    // Шаги могли опустошить цвета: убираем неиспользуемые и снова упорядочиваем по площади.
    pattern = _compactPattern(pattern, cells);
    times['steps'] = lap();
    return GeneratedPattern(
      grid: pattern.grid,
      palette: pattern.palette,
      stats: _stats(
        pattern,
        cells,
        request.geometry,
        times,
        singlesBefore: request.steps.isEmpty && smoother == null ? null : singlesBefore,
      ),
    );
  }

  GenerationStats _stats(
    GeneratedPattern pattern,
    SampledCells cells,
    GridGeometry geometry,
    Map<String, Duration> times, {
    int? singlesBefore,
  }) {
    final List<Lab> paletteLab = <Lab>[for (final PaletteEntry e in pattern.palette) Lab.fromRgb(e.rgb)];
    final Set<int> used = <int>{};
    double sum = 0;
    int counted = 0;
    for (int i = 0; i < cells.colors.length; i++) {
      final Rgb? source = cells.colors[i];
      final int value = pattern.grid.at(i % cells.columns, i ~/ cells.columns);
      if (source == null || value == 0) continue;
      used.add(value);
      sum += deltaE2000(Lab.fromRgb(source), paletteLab[value - 1]);
      counted++;
    }
    return GenerationStats(
      singleCells: countSingleCells(pattern.grid, geometry),
      singleCellsBefore: singlesBefore,
      colorCount: used.length,
      meanDeltaE: counted == 0 ? 0 : sum / counted,
      stageTimes: times,
    );
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

    if (candidates == null) return <PaletteEntry>{for (final Rgb mean in means) PaletteEntry(rgb: mean)}.toList();

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
  GeneratedPattern _compact(Uint16List values, List<PaletteEntry> palette, SampledCells cells) =>
      _compactOrdered(values, palette, cells).$1;

  GeneratedPattern _compactPattern(GeneratedPattern pattern, SampledCells cells) {
    final Uint16List values = Uint16List(cells.columns * cells.rows);
    for (int i = 0; i < values.length; i++) {
      values[i] = pattern.grid.at(i % cells.columns, i ~/ cells.columns);
    }
    return _compactOrdered(values, pattern.palette, cells).$1;
  }

  /// То же, что [_compact], и ещё порядок: какие цвета исходной палитры остались и в каком порядке.
  (GeneratedPattern, List<int>) _compactOrdered(Uint16List values, List<PaletteEntry> palette, SampledCells cells) {
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
    return (
      GeneratedPattern(
        grid: Grid.fromCells(
          width: cells.columns,
          height: cells.rows,
          cells: <int>[for (final int v in values) v == 0 ? 0 : remap[v - 1]],
        ),
        palette: <PaletteEntry>[for (final int i in order) palette[i]],
      ),
      order,
    );
  }
}
