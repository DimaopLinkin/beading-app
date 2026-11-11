import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/cell_costs.dart';
import 'package:beading/domain/image_to_grid/cell_labeler.dart';
import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/palette_builder.dart';
import 'package:beading/domain/image_to_grid/palette_constraint.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import '../grid/fake_cell_metrics.dart';

const FakeCellMetrics _metrics = FakeCellMetrics(1, 1);

/// Картинка [width]×[height]: фон [background], прямоугольники — `(x0, y0, x1, y1, цвет)`.
SourceImage painted(int width, int height, int background, List<(int, int, int, int, int)> rects) {
  final Uint8List bytes = Uint8List(width * height * 4);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      int color = background;
      for (final (int x0, int y0, int x1, int y1, int c) in rects) {
        if (x >= x0 && x < x1 && y >= y0 && y < y1) color = c;
      }
      final int o = (y * width + x) * 4;
      bytes[o] = (color >> 16) & 255;
      bytes[o + 1] = (color >> 8) & 255;
      bytes[o + 2] = color & 255;
      bytes[o + 3] = 255;
    }
  }
  return SourceImage(width: width, height: height, rgba: bytes);
}

ImageToGridRequest pixelRequest(
  SourceImage image, {
  required int columns,
  required int rows,
  int maxColors = 8,
  PaletteConstraint constraint = const PaletteConstraint.free(),
  List<PatternStep> steps = const <PatternStep>[],
  GridGeometry geometry = const GridGeometry.rectangular(),
}) => ImageToGridRequest(
  image: image,
  geometry: geometry,
  metrics: _metrics,
  columns: columns,
  rows: rows,
  maxColors: maxColors,
  constraint: constraint,
  paletteBuilder: const AccentPaletteBuilder(),
  labeler: const VotingCellLabeler(),
  steps: steps,
);

WorkImage workOf(SourceImage image, int columns, int rows) => WorkImage.fromSource(
  image: image,
  geometry: const GridGeometry.rectangular(),
  metrics: _metrics,
  columns: columns,
  rows: rows,
);

double nearestDe(List<PaletteEntry> palette, int color) {
  final Lab target = Lab.fromRgb(Rgb((color >> 16) & 255, (color >> 8) & 255, color & 255));
  return palette.map((e) => deltaE2000(Lab.fromRgb(e.rgb), target)).reduce(math.min);
}

class _CaptureCosts implements PatternStep {
  _CaptureCosts(this.onCosts);

  final void Function(CellCosts? costs) onCosts;

  @override
  GeneratedPattern apply(GeneratedPattern pattern, PatternStepContext context) {
    onCosts(context.costs);
    return pattern;
  }
}

void main() {
  group('AccentPaletteBuilder', () {
    test('маленькое яркое пятно (0,5 % площади) получает свой цвет при 8 цветах', () {
      // Фон — плавный градиент оттенков серого и бежевого, пятно 6×8 px из 240×240: 0,08 %... берём 17×17 ≈ 0,5 %.
      final SourceImage image = painted(240, 240, 0x808080, <(int, int, int, int, int)>[
        (0, 0, 120, 240, 0xC8B89A),
        (120, 0, 240, 120, 0x404858),
        (60, 60, 77, 77, 0xE02020),
      ]);
      final List<PaletteEntry> palette = const AccentPaletteBuilder().build(
        PaletteRequest(work: workOf(image, 40, 40), maxColors: 8, constraint: const PaletteConstraint.free()),
      );
      expect(palette.length, lessThanOrEqualTo(8));
      expect(nearestDe(palette, 0xE02020), lessThan(6));
    });

    test('единичный пиксель-помеха не получает цвета', () {
      final SourceImage image = painted(120, 120, 0x808080, <(int, int, int, int, int)>[
        (0, 0, 60, 120, 0xC8B89A),
        (10, 10, 11, 11, 0xFF00FF),
      ]);
      final List<PaletteEntry> palette = const AccentPaletteBuilder().build(
        PaletteRequest(work: workOf(image, 20, 20), maxColors: 4, constraint: const PaletteConstraint.free()),
      );
      expect(nearestDe(palette, 0xFF00FF), greaterThan(12));
    });

    test('с каталогом из 400 позиций и 20 цветами палитра — ровно 20 разных позиций', () {
      final math.Random random = math.Random(5);
      final List<PaletteEntry> catalog = <PaletteEntry>[
        for (int i = 0; i < 400; i++)
          PaletteEntry(rgb: Rgb(random.nextInt(256), random.nextInt(256), random.nextInt(256))),
      ];
      // Много оттенков: каждый столбец картинки — свой цвет.
      final Uint8List bytes = Uint8List(200 * 100 * 4);
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 200; x++) {
          final int o = (y * 200 + x) * 4;
          bytes[o] = x + 20;
          bytes[o + 1] = (y * 2) % 256;
          bytes[o + 2] = 255 - x;
          bytes[o + 3] = 255;
        }
      }
      final List<PaletteEntry> palette = const AccentPaletteBuilder().build(
        PaletteRequest(
          work: workOf(SourceImage(width: 200, height: 100, rgba: bytes), 40, 20),
          maxColors: 20,
          constraint: PaletteConstraint.list(catalog),
        ),
      );
      expect(palette.length, 20);
      expect(palette.toSet().length, 20);
      expect(catalog.toSet().containsAll(palette), isTrue);
    });

    test('кандидатов не больше цветов: берутся все', () {
      final List<PaletteEntry> two = <PaletteEntry>[
        const PaletteEntry(rgb: Rgb(255, 0, 0)),
        const PaletteEntry(rgb: Rgb(0, 0, 255)),
      ];
      final SourceImage image = SourceImage.solid(width: 20, height: 20, r: 10, g: 200, b: 10);
      final List<PaletteEntry> palette = const AccentPaletteBuilder().build(
        PaletteRequest(work: workOf(image, 4, 4), maxColors: 5, constraint: PaletteConstraint.list(two)),
      );
      expect(palette, two);
    });

    test('однотонная картинка — один цвет, близкий к исходному', () {
      final List<PaletteEntry> palette = const AccentPaletteBuilder().build(
        PaletteRequest(
          work: workOf(SourceImage.solid(width: 30, height: 30, r: 40, g: 120, b: 200), 5, 5),
          maxColors: 6,
          constraint: const PaletteConstraint.free(),
        ),
      );
      expect(palette.length, 1);
      expect(nearestDe(palette, 0x2878C8), lessThan(1));
    });

    test('детерминизм: тот же вход и зерно — та же палитра', () {
      final SourceImage image = painted(120, 120, 0x808080, <(int, int, int, int, int)>[
        (0, 0, 60, 120, 0xC8B89A),
        (70, 70, 100, 100, 0x2030E0),
      ]);
      PaletteRequest req() => PaletteRequest(
        work: workOf(image, 20, 20),
        maxColors: 6,
        constraint: const PaletteConstraint.free(),
        seed: 3,
      );
      expect(const AccentPaletteBuilder().build(req()), const AccentPaletteBuilder().build(req()));
    });

    test('1000×1000 → 150×200, 30 цветов быстрее 2 с', () {
      final Uint8List bytes = Uint8List(1000 * 1000 * 4);
      final math.Random random = math.Random(1);
      for (int i = 0; i < 1000 * 1000; i++) {
        final int x = i % 1000;
        final int y = i ~/ 1000;
        bytes[i * 4] = (x * 255 ~/ 999 + random.nextInt(12)).clamp(0, 255);
        bytes[i * 4 + 1] = (y * 255 ~/ 999 + random.nextInt(12)).clamp(0, 255);
        bytes[i * 4 + 2] = (x + y) % 256;
        bytes[i * 4 + 3] = 255;
      }
      final SourceImage image = SourceImage(width: 1000, height: 1000, rgba: bytes);
      final Stopwatch clock = Stopwatch()..start();
      final GeneratedPattern pattern = const ImageToGridPipeline().run(
        pixelRequest(image, columns: 150, rows: 200, maxColors: 30),
      );
      expect(pattern.grid.width, 150);
      expect(clock.elapsedMilliseconds, lessThan(2000));
    });
  });

  group('VotingCellLabeler', () {
    test('клетка на границе 60/40 берёт цвет большей части', () {
      // Одна клетка: 6 px из 10 чёрные, 4 белые; в палитре чёрный, белый и серый — «смесь» не выигрывает.
      final SourceImage image = painted(10, 10, 0xFFFFFF, <(int, int, int, int, int)>[(0, 0, 6, 10, 0x000000)]);
      final List<Lab> palette = <Lab>[
        Lab.fromRgb(const Rgb(0, 0, 0)),
        Lab.fromRgb(const Rgb(255, 255, 255)),
        Lab.fromRgb(const Rgb(110, 110, 110)),
      ];
      final WorkImage work = workOf(image, 1, 1);
      final CellRegions regions = CellRegions.forGrid(
        geometry: const GridGeometry.rectangular(),
        metrics: _metrics,
        columns: 1,
        rows: 1,
        imageWidth: work.width,
        imageHeight: work.height,
      );
      final LabeledCells labeled = const VotingCellLabeler().label(work: work, regions: regions, palette: palette);
      expect(labeled.values.single, 1);
      expect(labeled.costs.cheapest(0), 0);
      expect(labeled.costs.at(0, 0), lessThan(labeled.costs.at(0, 1)));
    });

    test('прозрачные клетки получают 0', () {
      final Uint8List bytes = Uint8List(4 * 4 * 4);
      for (int i = 0; i < 16; i++) {
        bytes[i * 4] = 255;
        bytes[i * 4 + 3] = i % 4 < 2 ? 255 : 0;
      }
      final SourceImage image = SourceImage(width: 4, height: 4, rgba: bytes);
      final GeneratedPattern pattern = const ImageToGridPipeline().run(
        pixelRequest(image, columns: 4, rows: 4, maxColors: 2),
      );
      expect(pattern.grid.at(0, 0), isNot(0));
      expect(pattern.grid.at(3, 0), 0);
    });
  });

  group('CellRegions', () {
    test('клетки одного ряда стыкуются без щелей; у пейота ряды сдвинуты', () {
      for (final GridGeometry geometry in <GridGeometry>[
        const GridGeometry.rectangular(),
        const GridGeometry.peyote(),
      ]) {
        final WorkImage work = WorkImage.fromSource(
          image: SourceImage.solid(width: 50, height: 50, r: 1, g: 2, b: 3),
          geometry: geometry,
          metrics: _metrics,
          columns: 10,
          rows: 10,
        );
        final CellRegions regions = CellRegions.forGrid(
          geometry: geometry,
          metrics: _metrics,
          columns: 10,
          rows: 10,
          imageWidth: work.width,
          imageHeight: work.height,
        );
        for (int cell = 0; cell < 100; cell++) {
          expect(regions.right(cell), greaterThan(regions.left(cell)));
          expect(regions.bottom(cell), greaterThan(regions.top(cell)));
          expect(regions.right(cell), lessThanOrEqualTo(work.width));
          expect(regions.bottom(cell), lessThanOrEqualTo(work.height));
        }
      }
    });
  });

  group('конвейер на пиксельных стадиях', () {
    test('шаг получает цены с числом столбцов, равным палитре результата', () {
      final SourceImage image = painted(60, 60, 0xFFFFFF, <(int, int, int, int, int)>[(0, 0, 30, 60, 0x202020)]);
      CellCosts? seen;
      final GeneratedPattern pattern = const ImageToGridPipeline().run(
        pixelRequest(
          image,
          columns: 10,
          rows: 10,
          maxColors: 6,
          steps: <PatternStep>[_CaptureCosts((c) => seen = c)],
        ),
      );
      expect(seen, isNotNull);
      expect(seen!.colorCount, pattern.palette.length);
      expect(seen!.columns, 10);
      // Номер клетки в сетке — цвет с наименьшей ценой.
      for (int cell = 0; cell < 100; cell++) {
        final int value = pattern.grid.at(cell % 10, cell ~/ 10);
        expect(seen!.cheapest(cell), value - 1);
      }
    });

    test('путь T24 не получает цен', () {
      CellCosts? seen;
      bool called = false;
      const ImageToGridPipeline().run(
        ImageToGridRequest(
          image: SourceImage.solid(width: 8, height: 8, r: 9, g: 9, b: 9),
          geometry: const GridGeometry.rectangular(),
          metrics: _metrics,
          columns: 4,
          rows: 4,
          maxColors: 2,
          steps: <PatternStep>[
            _CaptureCosts((c) {
              called = true;
              seen = c;
            }),
          ],
        ),
      );
      expect(called, isTrue);
      expect(seen, isNull);
    });

    test('границы фигуры остаются чёткими, одиночных клеток нет', () {
      final SourceImage image = painted(100, 100, 0xF0F0F0, <(int, int, int, int, int)>[(25, 25, 75, 75, 0x3050A0)]);
      final GeneratedPattern pattern = const ImageToGridPipeline().run(
        pixelRequest(image, columns: 20, rows: 20, maxColors: 3),
      );
      expect(pattern.stats!.singleCells, 0);
      expect(pattern.stats!.colorCount, 2);
    });
  });
}
