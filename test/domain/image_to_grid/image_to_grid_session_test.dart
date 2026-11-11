import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/cell_labeler.dart';
import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/cleanup_steps.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_prefilter.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_session.dart';
import 'package:beading/domain/image_to_grid/label_smoother.dart';
import 'package:beading/domain/image_to_grid/palette_builder.dart';
import 'package:beading/domain/image_to_grid/palette_constraint.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import '../grid/fake_cell_metrics.dart';

/// Строитель палитры, который считает вызовы.
final class _SpyPalette implements PaletteBuilder {
  int calls = 0;

  @override
  List<PaletteEntry> build(PaletteRequest request) {
    calls++;
    return const AccentPaletteBuilder().build(request);
  }
}

final class _SpyLabeler implements CellLabeler {
  int calls = 0;

  @override
  LabeledCells label({required WorkImage work, required CellRegions regions, required List<Lab> palette}) {
    calls++;
    return const VotingCellLabeler().label(work: work, regions: regions, palette: palette);
  }
}

/// Цветные пятна с шумом: есть что чистить и из чего выбирать палитру.
SourceImage _photo() {
  const int w = 120;
  const int h = 90;
  final math.Random random = math.Random(3);
  final Uint8List bytes = Uint8List(w * h * 4);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final int o = (y * w + x) * 4;
      final int quadrant = (x < w ~/ 2 ? 0 : 1) + (y < h ~/ 2 ? 0 : 2);
      const List<List<int>> colors = <List<int>>[
        <int>[220, 40, 40],
        <int>[40, 200, 60],
        <int>[50, 60, 220],
        <int>[230, 220, 80],
      ];
      for (int c = 0; c < 3; c++) {
        bytes[o + c] = (colors[quadrant][c] + random.nextInt(41) - 20).clamp(0, 255);
      }
      bytes[o + 3] = 255;
    }
  }
  return SourceImage(width: w, height: h, rgba: bytes);
}

void main() {
  final SourceImage image = _photo();
  late _SpyPalette palette;
  late _SpyLabeler labeler;

  ImageToGridRequest build({
    SourceImage? source,
    int columns = 24,
    int maxColors = 6,
    double detail = 0.5,
    int minIsland = 3,
    double sigma = 9,
    bool draft = false,
    PaletteConstraint constraint = const PaletteConstraint.free(),
  }) => ImageToGridRequest(
    image: source ?? image,
    geometry: const GridGeometry.rectangular(),
    metrics: const FakeCellMetrics(1, 1),
    columns: columns,
    rows: columns * 3 ~/ 4,
    maxColors: maxColors,
    constraint: constraint,
    prefilter: EdgePreservingPrefilter(sigmaRange: sigma),
    paletteBuilder: palette,
    labeler: labeler,
    smoother: PottsLabelSmoother(detail: detail),
    steps: <RemoveIslandsStep>[RemoveIslandsStep(minIsland: minIsland)],
    draft: draft,
  );

  setUp(() {
    palette = _SpyPalette();
    labeler = _SpyLabeler();
  });

  test('второй такой же запрос не пересчитывает ни палитру, ни разметку и даёт тот же результат', () {
    final ImageToGridSession session = ImageToGridSession();
    final GeneratedPattern first = session.run(build());
    final GeneratedPattern second = session.run(build());
    expect(palette.calls, 1);
    expect(labeler.calls, 1);
    expect(second.grid, first.grid);
    expect(second.palette, first.palette);
    expect(second.stats!.stageTimes['palette'], Duration.zero);
  });

  test('смена очистки и детальности не вызывает стадии палитры и разметки (стадии 4–5)', () {
    final ImageToGridSession session = ImageToGridSession();
    session.run(build());
    final GeneratedPattern changed = session.run(build(detail: 0.9, minIsland: 2));
    expect(palette.calls, 1);
    expect(labeler.calls, 1);
    final GeneratedPattern cold = const ImageToGridPipeline().run(build(detail: 0.9, minIsland: 2));
    expect(changed.grid, cold.grid);
    expect(changed.palette, cold.palette);
  });

  test('смена числа цветов или зерна пересчитывает палитру и разметку, но не подготовку', () {
    final ImageToGridSession session = ImageToGridSession();
    session.run(build());
    final GeneratedPattern fewer = session.run(build(maxColors: 3));
    expect(palette.calls, 2);
    expect(labeler.calls, 2);
    expect(fewer.palette.length, lessThanOrEqualTo(3));
    expect(fewer.stats!.stageTimes['sample'], Duration.zero);
    final GeneratedPattern cold = const ImageToGridPipeline().run(build(maxColors: 3));
    expect(fewer.grid, cold.grid);
  });

  test('смена ограничения палитры равна по значению: тот же список — кеш, другой — пересчёт', () {
    final ImageToGridSession session = ImageToGridSession();
    final List<PaletteEntry> list = <PaletteEntry>[
      const PaletteEntry(rgb: Rgb(220, 40, 40)),
      const PaletteEntry(rgb: Rgb(40, 200, 60)),
      const PaletteEntry(rgb: Rgb(50, 60, 220)),
      const PaletteEntry(rgb: Rgb(230, 220, 80)),
      const PaletteEntry(rgb: Rgb(10, 10, 10)),
      const PaletteEntry(rgb: Rgb(250, 250, 250)),
      const PaletteEntry(rgb: Rgb(120, 120, 120)),
    ];
    session.run(build(constraint: PaletteConstraint.list(list)));
    session.run(build(constraint: PaletteConstraint.list(<PaletteEntry>[...list])));
    expect(palette.calls, 1);
    session.run(build(constraint: PaletteConstraint.list(list.sublist(0, 6))));
    expect(palette.calls, 2);
  });

  test('смена размера схемы, фильтра или картинки пересчитывает всё', () {
    final ImageToGridSession session = ImageToGridSession();
    session.run(build());
    session.run(build(columns: 30));
    expect(palette.calls, 2);
    session.run(build(columns: 30, sigma: 12));
    expect(palette.calls, 3);
    final SourceImage other = SourceImage(
      width: image.width,
      height: image.height,
      rgba: Uint8List.fromList(image.rgba),
    );
    session.run(build(columns: 30, sigma: 12, source: other));
    expect(palette.calls, 4);
  });

  test('черновик и полный расчёт не сбрасывают кеши друг друга', () {
    final ImageToGridSession session = ImageToGridSession();
    final GeneratedPattern full = session.run(build());
    final GeneratedPattern draft = session.run(build(draft: true));
    expect(palette.calls, 2);
    session.run(build(draft: true, detail: 0.8));
    session.run(build(detail: 0.8));
    expect(palette.calls, 2, reason: 'оба кеша тёплые');
    expect(draft.grid.width, full.grid.width);
    expect(draft.grid.height, full.grid.height);
  });

  test('черновик считается на рабочей картинке в 2 пикселя на клетку', () {
    final WorkImage work = WorkImage.fromSource(
      image: image,
      geometry: const GridGeometry.rectangular(),
      metrics: const FakeCellMetrics(1, 1),
      columns: 24,
      rows: 18,
      scale: WorkImage.draftScale,
    );
    expect(work.scale, 2);
    expect(work.width, 48);
  });

  test('сессия без кеша (разовый run) даёт тот же результат, что сессия', () {
    final GeneratedPattern cold = const ImageToGridPipeline().run(build());
    final GeneratedPattern warm = ImageToGridSession().run(build());
    expect(warm.grid, cold.grid);
    expect(warm.palette, cold.palette);
    expect(warm.stats!.singleCells, cold.stats!.singleCells);
  });
}
