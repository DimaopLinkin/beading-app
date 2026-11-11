import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/accent_refill.dart';
import 'package:beading/domain/image_to_grid/background_stage.dart';
import 'package:beading/domain/image_to_grid/blend_suggester.dart';
import 'package:beading/domain/image_to_grid/cell_edges.dart';
import 'package:beading/domain/image_to_grid/cell_labeler.dart';
import 'package:beading/domain/image_to_grid/cell_neighbors.dart';
import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/cell_sampler.dart';
import 'package:beading/domain/image_to_grid/color_assigner.dart';
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

  /// Один расчёт. С [cache] стадии, чьи входные данные не изменились с прошлого запуска, не пересчитываются
  /// (T58, [ImageToGridSession]); результат тот же, что без кеша. Кеш работает только на пиксельном пути.
  GeneratedPattern run(ImageToGridRequest request, {PixelStageCache? cache}) {
    final Stopwatch clock = Stopwatch()..start();
    final Map<String, Duration> times = <String, Duration>{};
    Duration lap() {
      final Duration elapsed = clock.elapsed;
      clock.reset();
      return elapsed;
    }

    if (request.usesPixelStages) return _runPixelStages(request, clock, times, lap, cache ?? PixelStageCache());

    SourceImage image = request.image;
    Float32List? importance = request.effectiveImportance;
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
      cellColors: cells.colors,
    );
    for (final PatternStep step in request.steps) {
      pattern = step.apply(pattern, context);
    }
    pattern = _compactPattern(_backgroundStage(request, pattern, cells), cells);
    times['steps'] = lap();
    final List<BlendSuggestion> blends = _blends(request, pattern, cells);
    if (request.suggestBlends) times['blends'] = lap();
    return GeneratedPattern(
      grid: pattern.grid,
      palette: pattern.palette,
      stats: _stats(pattern, cells, request.geometry, times),
      blendSuggestions: blends,
    );
  }

  /// Путь по ADR-0004: рабочее изображение → палитра по пикселям → цвет клетки голосованием → шаги с ценами цветов.
  ///
  /// Три группы стадий кешируются по значениям, от которых зависят: подготовка (картинка, размер схемы, фильтр),
  /// палитра (+ число цветов, ограничение, зерно) и разметка (+ разметчик). Сглаживание и очистка считаются каждый раз.
  GeneratedPattern _runPixelStages(
    ImageToGridRequest request,
    Stopwatch clock,
    Map<String, Duration> times,
    Duration Function() lap,
    PixelStageCache cache,
  ) {
    // Стадии, взятые из кеша, стоят ноль: набор ключей не зависит от кеша.
    times['sample'] = times['palette'] = Duration.zero;
    final List<Object?> prepareKey = <Object?>[
      request.image,
      request.importance,
      request.subjectMask,
      request.background,
      request.geometry,
      request.metrics,
      request.columns,
      request.rows,
      request.draft,
      request.prefilter,
    ];
    _Prepared? prepared = cache._prepared;
    if (prepared == null || !_sameKey(cache._prepareKey, prepareKey)) {
      cache
        .._prepared = null
        .._palette = null
        .._labeled = null;
      prepared = _prepare(request);
      cache
        .._prepareKey = prepareKey
        .._prepared = prepared;
      times['sample'] = lap();
    }
    final SampledCells cells = prepared.cells;
    final CellRegions regions = prepared.regions;
    final WorkImage work = prepared.work;

    final PaletteBuilder paletteBuilder = request.paletteBuilder ?? const AccentPaletteBuilder();
    final List<Object?> paletteKey = <Object?>[request.maxColors, request.constraint, request.seed, paletteBuilder];
    List<PaletteEntry>? palette = cache._palette;
    if (palette == null || !_sameKey(cache._paletteKey, paletteKey)) {
      cache
        .._labeled = null
        .._palette = null;
      palette = paletteBuilder.build(
        PaletteRequest(
          work: work,
          maxColors: request.maxColors,
          constraint: request.constraint,
          seed: request.seed,
          regions: regions,
        ),
      );
      cache
        .._paletteKey = paletteKey
        .._palette = palette;
      times['palette'] = lap();
    }

    final CellLabeler labeler = request.labeler ?? const VotingCellLabeler();
    _Labeled? labeledStage = cache._labeled;
    if (labeledStage == null || labeledStage.labeler != labeler) {
      final LabeledCells labeled = labeler.label(
        work: work,
        regions: regions,
        palette: <Lab>[for (final PaletteEntry e in palette) Lab.fromRgb(e.rgb)],
      );
      labeledStage = _Labeled(
        labeler: labeler,
        labeled: labeled,
        singlesBefore: countSingleCells(
          Grid.fromCells(width: cells.columns, height: cells.rows, cells: labeled.values.toList()),
          request.geometry,
        ),
      );
      cache._labeled = labeledStage;
    }
    final LabeledCells labeled = labeledStage.labeled;
    final int singlesBefore = labeledStage.singlesBefore;
    final CellNeighbors neighbors = prepared.neighbors;
    final Float32List edges = prepared.edges;
    final LabelSmoother? smoother = request.smoother;
    final Uint16List values = smoother == null
        ? labeled.values
        : smoother.smooth(
            values: Uint16List.fromList(labeled.values),
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
      cellColors: cells.colors,
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
    pattern = _compactPattern(_backgroundStage(request, pattern, cells), cells);
    times['steps'] = lap();
    final List<BlendSuggestion> blends = _blends(request, pattern, cells);
    if (request.suggestBlends) times['blends'] = lap();
    return GeneratedPattern(
      grid: pattern.grid,
      palette: pattern.palette,
      blendSuggestions: blends,
      stats: _stats(
        pattern,
        cells,
        request.geometry,
        times,
        singlesBefore: request.steps.isEmpty && smoother == null ? null : singlesBefore,
      ),
    );
  }

  /// Первая группа стадий пиксельного пути: рабочая картинка, фильтр, цвета клеток, области, соседи и края.
  _Prepared _prepare(ImageToGridRequest request) {
    WorkImage work = WorkImage.fromSource(
      image: request.image,
      importance: request.effectiveImportance,
      geometry: request.geometry,
      metrics: request.metrics,
      columns: request.columns,
      rows: request.rows,
      scale: request.draft ? WorkImage.draftScale : null,
    );
    final ImagePrefilter? prefilter = request.prefilter;
    if (prefilter != null) work = prefilter.apply(work);
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
    return _Prepared(
      work: work,
      cells: cells,
      regions: regions,
      neighbors: CellNeighbors.of(geometry: request.geometry, columns: cells.columns, rows: cells.rows),
      edges: cellEdges(work, regions),
    );
  }

  /// Бленды двух ниток (T57): только если запрос просил; по цветам клеток после ресэмплинга.
  List<BlendSuggestion> _blends(ImageToGridRequest request, GeneratedPattern pattern, SampledCells cells) =>
      request.suggestBlends ? suggestBlends(pattern, cells.colors) : const <BlendSuggestion>[];

  /// Фон и обводка (T55): после всех шагов, по маске объекта на уровне клеток.
  GeneratedPattern _backgroundStage(ImageToGridRequest request, GeneratedPattern pattern, SampledCells cells) {
    final Uint8List? mask = request.subjectMask;
    if (mask == null || !request.usesBackgroundStage) return pattern;
    final CellRegions regions = CellRegions.forGrid(
      geometry: request.geometry,
      metrics: request.metrics,
      columns: request.columns,
      rows: request.rows,
      imageWidth: request.image.width,
      imageHeight: request.image.height,
    );
    return BackgroundStage.apply(
      pattern: pattern,
      cellColors: cells.colors,
      subject: subjectCellsFrom(mask: mask, imageWidth: request.image.width, regions: regions),
      neighbors: CellNeighbors.of(geometry: request.geometry, columns: cells.columns, rows: cells.rows),
      mode: request.background,
      outline: request.outline,
      maxColors: request.maxColors,
      constraint: request.constraint,
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

/// Результаты стадий пиксельного пути между запусками одной сессии (T58).
///
/// Хранит только последние результаты; ключ каждой группы — значения, от которых она зависит. Совпал ключ — стадия
/// не считается заново, изменился — пересчитывается она и все после неё.
final class PixelStageCache {
  List<Object?>? _prepareKey;
  _Prepared? _prepared;
  List<Object?>? _paletteKey;
  List<PaletteEntry>? _palette;
  _Labeled? _labeled;
}

final class _Prepared {
  const _Prepared({
    required this.work,
    required this.cells,
    required this.regions,
    required this.neighbors,
    required this.edges,
  });

  final WorkImage work;
  final SampledCells cells;
  final CellRegions regions;
  final CellNeighbors neighbors;
  final Float32List edges;
}

final class _Labeled {
  const _Labeled({required this.labeler, required this.labeled, required this.singlesBefore});

  final CellLabeler labeler;
  final LabeledCells labeled;
  final int singlesBefore;
}

bool _sameKey(List<Object?>? a, List<Object?> b) {
  if (a == null || a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    // Картинку и маску сравниваем по тождеству: перебирать мегабайты пикселей незачем.
    final bool same = a[i] is SourceImage || a[i] is Float32List || a[i] is Uint8List
        ? identical(a[i], b[i])
        : a[i] == b[i];
    if (!same) return false;
  }
  return true;
}
