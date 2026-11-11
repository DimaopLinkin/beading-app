@Tags(<String>['gallery'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/image_to_grid/cell_costs.dart';
import 'package:beading/domain/image_to_grid/cell_labeler.dart';
import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/cell_sampler.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
import 'package:beading/domain/image_to_grid/image_prefilter.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/palette_builder.dart';
import 'package:beading/domain/image_to_grid/palette_constraint.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gallery_support.dart';

// Исследование A09 (docs/research/photo-to-pattern-a09.md): прототипы стадий поверх настоящего конвейера.
// Не код приложения и не эталон реализации: параметры подобраны на глаз по девяти фикстурам.
//
//     GALLERY_OUT=build/a09 flutter test --tags gallery test/gallery/a09_research_test.dart
//
// Пишет листы «фото / варианты» трёх групп (стадии, каталог, размер), подписи к ним (.txt) и metrics.md.

/// Местный контраст («ясность»): L += amount × (L − размытая L), радиус в клетках.
final class LocalContrastPrefilter implements ImagePrefilter {
  const LocalContrastPrefilter(this.inner, {this.amount = 0.35, this.radiusCells = 2, this.limit = 10});

  final ImagePrefilter inner;
  final double amount;
  final double radiusCells;

  /// Потолок поправки светлоты: без него у контрастных краёв появляются светлые ореолы.
  final double limit;

  @override
  WorkImage apply(WorkImage image) {
    final WorkImage base = inner.apply(image);
    final int r = math.max(1, (radiusCells * base.scale).round());
    final Float32List blur = boxBlur(boxBlur(base.lightness, base.width, base.height, r), base.width, base.height, r);
    final Float32List l = Float32List(base.lightness.length);
    for (int i = 0; i < l.length; i++) {
      l[i] = (base.lightness[i] + (amount * (base.lightness[i] - blur[i])).clamp(-limit, limit)).clamp(0, 100);
    }
    return base.withColors(lightness: l, a: base.a, b: base.b);
  }
}

Float32List boxBlur(Float32List data, int w, int h, int r) {
  final Float32List tmp = Float32List(w * h);
  final Float32List out = Float32List(w * h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      double s = 0;
      int n = 0;
      for (int xx = math.max(0, x - r); xx <= math.min(w - 1, x + r); xx++) {
        s += data[y * w + xx];
        n++;
      }
      tmp[y * w + x] = s / n;
    }
  }
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      double s = 0;
      int n = 0;
      for (int yy = math.max(0, y - r); yy <= math.min(h - 1, y + r); yy++) {
        s += tmp[yy * w + x];
        n++;
      }
      out[y * w + x] = s / n;
    }
  }
  return out;
}

/// Палитра с настоящими крайними тонами: самый тёмный и самый светлый цвет палитры сдвигаются к 1-му и 99-му
/// перцентилю светлоты рабочих пикселей (k-means даёт средние, поэтому чёрного и белого в схеме нет).
final class RangePaletteBuilder implements PaletteBuilder {
  const RangePaletteBuilder({this.inner = const AccentPaletteBuilder(), this.low = 0.02, this.high = 0.98});

  final AccentPaletteBuilder inner;
  final double low;
  final double high;

  static final List<String> log = <String>[];

  @override
  List<PaletteEntry> build(PaletteRequest request) {
    final List<PaletteEntry>? candidates = request.constraint.candidates;
    final List<PaletteEntry> free = inner.build(
      PaletteRequest(
        work: request.work,
        maxColors: request.maxColors,
        constraint: const PaletteConstraint.free(),
        seed: request.seed,
        regions: request.regions,
      ),
    );
    final List<Lab> labs = <Lab>[for (final PaletteEntry e in free) Lab.fromRgb(e.rgb)];
    if (labs.length < 3) return candidates == null ? free : inner.build(request);
    final List<double> ls = <double>[
      for (int i = 0; i < request.work.lightness.length; i++)
        if (request.work.alpha[i] >= 0.5) request.work.lightness[i],
    ]..sort();
    final double pLow = ls[(ls.length * low).floor()];
    final double pHigh = ls[math.min(ls.length - 1, (ls.length * high).floor())];
    int dark = 0;
    int light = 0;
    for (int i = 0; i < labs.length; i++) {
      if (labs[i].l < labs[dark].l) dark = i;
      if (labs[i].l > labs[light].l) light = i;
    }
    log.add(
      'палитра L ${labs[dark].l.toStringAsFixed(0)}..${labs[light].l.toStringAsFixed(0)}, '
      'фото 1–99 % L ${pLow.toStringAsFixed(0)}..${pHigh.toStringAsFixed(0)}',
    );
    if (pLow < labs[dark].l) labs[dark] = Lab(pLow, labs[dark].a, labs[dark].b);
    if (pHigh > labs[light].l) labs[light] = Lab(pHigh, labs[light].a, labs[light].b);
    if (candidates == null) return <PaletteEntry>[for (final Lab c in labs) PaletteEntry(rgb: c.toRgb())];
    // Каталог: каждому цвету ближайшая свободная позиция.
    final List<Lab> catalog = <Lab>[for (final PaletteEntry e in candidates) Lab.fromRgb(e.rgb)];
    final Set<int> taken = <int>{};
    for (final Lab c in labs) {
      int best = -1;
      double bestD = double.infinity;
      for (int j = 0; j < catalog.length; j++) {
        if (taken.contains(j)) continue;
        final double d = deltaE2000(c, catalog[j]);
        if (d < bestD) {
          bestD = d;
          best = j;
        }
      }
      if (best >= 0) taken.add(best);
    }
    return <PaletteEntry>[for (final int j in taken) candidates[j]];
  }
}

/// Голосование с весом «заметности» пикселя (по мотивам DPID, Weber и др. 2016): пиксель, который отличается от
/// своей окрестности, весит больше, поэтому тонкая линия или блик внутри клетки не растворяется в фоне.
final class DetailCellLabeler implements CellLabeler {
  const DetailCellLabeler({this.lambda = 1, this.floor = 4});

  final double lambda;
  final double floor;

  @override
  LabeledCells label({required WorkImage work, required CellRegions regions, required List<Lab> palette}) {
    final int w = work.width;
    final int h = work.height;
    final int r = work.scale;
    final Float32List ml = boxBlur(work.lightness, w, h, r);
    final Float32List ma = boxBlur(work.a, w, h, r);
    final Float32List mb = boxBlur(work.b, w, h, r);
    final int cells = regions.columns * regions.rows;
    final int k = palette.length;
    final Float32List costs = Float32List(cells * k);
    final Uint16List values = Uint16List(cells);
    final Float64List sum = Float64List(k);
    for (int cell = 0; cell < cells; cell++) {
      sum.fillRange(0, k, 0);
      double total = 0;
      double alphaSum = 0;
      int area = 0;
      for (int y = regions.top(cell); y < regions.bottom(cell); y++) {
        for (int x = regions.left(cell); x < regions.right(cell); x++) {
          final int p = y * w + x;
          area++;
          alphaSum += work.alpha[p];
          if (work.alpha[p] < 0.5) continue;
          final double dl = work.lightness[p] - ml[p];
          final double da = work.a[p] - ma[p];
          final double db = work.b[p] - mb[p];
          final double weight = floor + math.pow(math.sqrt(dl * dl + da * da + db * db), lambda);
          total += weight;
          for (int c = 0; c < k; c++) {
            final double el = work.lightness[p] - palette[c].l;
            final double ea = work.a[p] - palette[c].a;
            final double eb = work.b[p] - palette[c].b;
            sum[c] += weight * math.sqrt(el * el + ea * ea + eb * eb);
          }
        }
      }
      if (area == 0 || total == 0 || alphaSum / area < 0.5) continue;
      int best = 0;
      for (int c = 0; c < k; c++) {
        costs[cell * k + c] = sum[c] / total;
        if (costs[cell * k + c] < costs[cell * k + best]) best = c;
      }
      values[cell] = best + 1;
    }
    return LabeledCells(
      values: values,
      costs: CellCosts(columns: regions.columns, rows: regions.rows, colorCount: k, values: costs),
    );
  }
}

ImageToGridRequest build(
  SourceImage image,
  GalleryTarget target, {
  List<CatalogColor> catalog = const <CatalogColor>[],
  GenerationPreset preset = GenerationPreset.balanced,
  bool tone = false,
  bool range = false,
  bool detail = false,
}) {
  final bool beads = target.metrics is BeadSize;
  final ImageToGridSettings settings = ImageToGridSettings(
    technique: target.technique,
    columns: target.columns,
    maxColors: target.maxColors,
    paletteSource: catalog.isEmpty ? PaletteSource.free : PaletteSource.catalog,
    preset: preset,
  );
  final ImageToGridRequest r = settings.toRequest(image: image, catalog: catalog);
  final CellMetrics metrics = beads ? r.metrics : target.metrics;
  return ImageToGridRequest(
    image: image,
    geometry: r.geometry,
    metrics: metrics,
    columns: target.columns,
    rows: GridSizing.rowsForColumns(
      imageWidth: image.width,
      imageHeight: image.height,
      geometry: r.geometry,
      metrics: metrics,
      columns: target.columns,
    ),
    maxColors: target.maxColors,
    constraint: r.constraint,
    prefilter: tone ? LocalContrastPrefilter(r.prefilter!) : r.prefilter,
    paletteBuilder: range ? const RangePaletteBuilder() : r.paletteBuilder,
    labeler: detail ? const DetailCellLabeler() : r.labeler,
    smoother: r.smoother,
    refillFreedColors: r.refillFreedColors,
    steps: r.steps,
  );
}

/// Метрики «структуры»: отношение разброса светлоты схемы к фото и корреляция светлоты по рабочим пикселям.
({double contrast, double corr}) structure(GeneratedPattern pattern, ImageToGridRequest request) {
  final WorkImage work = WorkImage.fromSource(
    image: request.image,
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
  final List<double> pl = <double>[for (final PaletteEntry e in pattern.palette) Lab.fromRgb(e.rgb).l];
  double sx = 0;
  double sy = 0;
  double sxx = 0;
  double syy = 0;
  double sxy = 0;
  int n = 0;
  for (int cell = 0; cell < regions.columns * regions.rows; cell++) {
    final int v = pattern.grid.at(cell % regions.columns, cell ~/ regions.columns);
    if (v == 0) continue;
    final double y = pl[v - 1];
    for (int yy = regions.top(cell); yy < regions.bottom(cell); yy++) {
      for (int xx = regions.left(cell); xx < regions.right(cell); xx++) {
        final double x = work.lightness[yy * work.width + xx];
        sx += x;
        sy += y;
        sxx += x * x;
        syy += y * y;
        sxy += x * y;
        n++;
      }
    }
  }
  final double vx = sxx / n - (sx / n) * (sx / n);
  final double vy = syy / n - (sy / n) * (sy / n);
  final double cov = sxy / n - (sx / n) * (sy / n);
  return (contrast: math.sqrt(vy / (vx + 1e-9)), corr: cov / math.sqrt(vx * vy + 1e-9));
}

final class Variant {
  const Variant(this.title, this.make, {this.target});

  final String title;
  final GalleryTarget? target;
  final ImageToGridRequest Function(SourceImage image, GalleryTarget target) make;
}

void main() {
  testWidgets('A09: прототипы', (tester) async {
    final String out = Platform.environment['GALLERY_OUT'] ?? 'build/a09';
    Directory(out).createSync(recursive: true);
    await tester.runAsync(() async {
      final List<CatalogColor> catalog = loadBeadCatalog();
      final List<CatalogColor> solid = <CatalogColor>[
        for (final CatalogColor c in catalog)
          if (c.finish == 'opaque' || c.finish == 'matte') c,
      ];
      final List<GalleryPhoto> photos = await loadPhotos();
      const ImageToGridPipeline pipeline = ImageToGridPipeline();
      final GalleryTarget loom = galleryTargets[0];
      final GalleryTarget stitch = galleryTargets[2];
      GalleryTarget sized(GalleryTarget t, int columns, int colors) => GalleryTarget(
        id: t.id,
        technique: t.technique,
        metrics: t.metrics,
        columns: columns,
        maxColors: colors,
      );

      final Map<String, List<Variant>> groups = <String, List<Variant>>{
        'stages': <Variant>[
          const Variant('сейчас (сбалансированно)', build),
          Variant('+ крайние тона', (i, t) => build(i, t, range: true)),
          Variant('+ местный контраст', (i, t) => build(i, t, tone: true)),
          Variant('+ заметные детали', (i, t) => build(i, t, detail: true)),
          Variant('всё вместе', (i, t) => build(i, t, range: true, tone: true, detail: true)),
        ],
        'catalog': <Variant>[
          Variant('каталог, сейчас', (i, t) => build(i, t, catalog: catalog)),
          Variant('каталог: только непрозрачный и матовый', (i, t) => build(i, t, catalog: solid)),
          Variant(
            'непрозрачный и матовый + всё вместе',
            (i, t) => build(i, t, catalog: solid, range: true, tone: true, detail: true),
          ),
        ],
        'size': <Variant>[
          const Variant('по умолчанию', build),
          Variant('×1,5', build, target: sized(loom, 60, 14)),
          Variant('×2', build, target: sized(loom, 80, 18)),
          Variant('×3', build, target: sized(loom, 120, 24)),
          Variant(
            '×3 + всё вместе',
            (i, t) => build(i, t, range: true, tone: true, detail: true),
            target: sized(loom, 120, 24),
          ),
        ],
      };
      final StringBuffer md = StringBuffer()
        ..writeln('| Фото | Вид | Группа | Вариант | Размер | Цветов | Одиночных | ΔE2000 | Контраст | Корреляция L |')
        ..writeln('|---|---|---|---|---|---|---|---|---|---|');
      final StringBuffer finishes = StringBuffer();
      for (final GalleryPhoto photo in photos) {
        for (final GalleryTarget target in <GalleryTarget>[loom, stitch]) {
          for (final MapEntry<String, List<Variant>> group in groups.entries) {
            if (group.key == 'catalog' && !target.isBeads) continue;
            final List<GalleryRun> runs = <GalleryRun>[];
            for (final Variant v in group.value) {
              GalleryTarget t = v.target ?? target;
              if (!target.isBeads && v.target != null) {
                t = sized(stitch, v.target!.columns * 3 ~/ 2, v.target!.maxColors + 6);
              }
              RangePaletteBuilder.log.clear();
              final ImageToGridRequest request = v.make(photo.image, t);
              final GeneratedPattern pattern = pipeline.run(request);
              final ({double contrast, double corr}) s = structure(pattern, request);
              runs.add(
                GalleryRun(
                  photo: photo,
                  target: t,
                  variant: GalleryVariant(id: v.title, title: v.title, build: (a, b, c) => request),
                  pattern: pattern,
                ),
              );
              md.writeln(
                '| ${photo.name} | ${target.id} | ${group.key} | ${v.title} | ${request.columns}×${request.rows} | '
                '${pattern.stats!.colorCount} | ${pattern.stats!.singleCells} | '
                '${pattern.stats!.meanDeltaE.toStringAsFixed(1)} | ${s.contrast.toStringAsFixed(2)} | '
                '${s.corr.toStringAsFixed(3)} | ${RangePaletteBuilder.log.join('; ')}',
              );
              if (group.key == 'catalog') {
                finishes.writeln(
                  '${photo.name} / ${v.title}: '
                  '${<String>[for (final PaletteEntry e in pattern.palette) '${e.catalog?.code}:${e.catalog?.finish}'].join(', ')}',
                );
              }
            }
            final Uint8List png = await renderSheet(photo, target, runs);
            File('$out/${photo.name}-${target.id}-${group.key}.png').writeAsBytesSync(png);
            File(
              '$out/${photo.name}-${target.id}-${group.key}.txt',
            ).writeAsStringSync(<String>['фото', for (final Variant v in group.value) v.title].join('\n'));
          }
        }
      }
      File('$out/metrics.md').writeAsStringSync(md.toString());
      File('$out/finishes.txt').writeAsStringSync(finishes.toString());
    });
  });
}
