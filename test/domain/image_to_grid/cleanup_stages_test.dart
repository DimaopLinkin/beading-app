import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/cell_costs.dart';
import 'package:beading/domain/image_to_grid/cell_neighbors.dart';
import 'package:beading/domain/image_to_grid/cleanup_steps.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/label_smoother.dart';
import 'package:beading/domain/image_to_grid/ordered_dither_step.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/pattern_metrics.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pixel_stages_test.dart' show painted;

const GridGeometry _rect = GridGeometry.rectangular();

GeneratedPattern _pattern(List<String> rows, List<int> colors) {
  final int h = rows.length;
  final int w = rows.first.length;
  return GeneratedPattern(
    grid: Grid.fromCells(
      width: w,
      height: h,
      cells: <int>[
        for (final String r in rows)
          for (final String c in r.split('')) c == '.' ? 0 : int.parse(c),
      ],
    ),
    palette: <PaletteEntry>[
      for (final int c in colors) PaletteEntry(rgb: Rgb((c >> 16) & 255, (c >> 8) & 255, c & 255)),
    ],
  );
}

PatternStepContext _context(
  GeneratedPattern p, {
  GridGeometry geometry = _rect,
  Map<int, double> importance = const <int, double>{},
  CellCosts? costs,
}) {
  final int n = p.grid.width * p.grid.height;
  return PatternStepContext(
    geometry: geometry,
    cellImportance: Float32List.fromList(<double>[for (int i = 0; i < n; i++) importance[i] ?? 1]),
    costs: costs,
  );
}

List<int> _cells(Grid g) => <int>[
  for (int y = 0; y < g.height; y++)
    for (int x = 0; x < g.width; x++) g.at(x, y),
];

/// Цены: 0 для цвета, который клетка имеет сейчас, 5 для остальных (шум «не по делу»).
CellCosts _flatCosts(GeneratedPattern p, {required int truth}) {
  final int n = p.grid.width * p.grid.height;
  final int k = p.palette.length;
  return CellCosts(
    columns: p.grid.width,
    rows: p.grid.height,
    colorCount: k,
    values: Float32List.fromList(<double>[
      for (int i = 0; i < n; i++)
        for (int c = 0; c < k; c++) c == truth - 1 ? 0 : 5,
    ]),
  );
}

void main() {
  _extra();
  group('PottsLabelSmoother', () {
    test('шум на однотонной картинке убирается полностью', () {
      final GeneratedPattern p = _pattern(
        <String>[
          '11111111',
          '11211211',
          '11111111',
          '12111121',
          '11111111',
          '11121111',
          '11111111',
          '11111111',
        ],
        <int>[0xCC3333, 0xCC3434],
      );
      final CellCosts costs = _flatCosts(p, truth: 1);
      final Uint16List out = const PottsLabelSmoother().smooth(
        values: Uint16List.fromList(_cells(p.grid)),
        costs: costs,
        neighbors: CellNeighbors.of(geometry: _rect, columns: 8, rows: 8),
        importance: Float32List(64)..fillRange(0, 64, 1),
        edges: Float32List(64),
      );
      expect(out.toSet(), <int>{1});
    });

    test('сильная цена цвета сохраняет клетку: край не стирается', () {
      final GeneratedPattern p = _pattern(<String>['111', '121', '111'], <int>[0xFFFFFF, 0x000000]);
      // Центру цвет 2 нужен очень сильно (цена цвета 1 — 40).
      final Float32List values = Float32List(9 * 2);
      for (int i = 0; i < 9; i++) {
        values[i * 2] = i == 4 ? 40 : 0;
        values[i * 2 + 1] = i == 4 ? 0 : 40;
      }
      final Uint16List out = const PottsLabelSmoother().smooth(
        values: Uint16List.fromList(_cells(p.grid)),
        costs: CellCosts(columns: 3, rows: 3, colorCount: 2, values: values),
        neighbors: CellNeighbors.of(geometry: _rect, columns: 3, rows: 3),
        importance: Float32List(9)..fillRange(0, 9, 1),
        edges: Float32List(9),
      );
      expect(out[4], 2);
    });

    test('«детально» оставляет больше, чем «гладко»; пустые клетки остаются пустыми', () {
      final GeneratedPattern p = _pattern(<String>['1.1', '121', '1.1'], <int>[0xFFFFFF, 0x000000]);
      Uint16List run(double detail) {
        final Float32List values = Float32List(9 * 2);
        for (int i = 0; i < 9; i++) {
          values[i * 2] = i == 4 ? 4 : 0;
          values[i * 2 + 1] = i == 4 ? 0 : 4;
        }
        return PottsLabelSmoother(detail: detail).smooth(
          values: Uint16List.fromList(_cells(p.grid)),
          costs: CellCosts(columns: 3, rows: 3, colorCount: 2, values: values),
          neighbors: CellNeighbors.of(geometry: _rect, columns: 3, rows: 3),
          importance: Float32List(9)..fillRange(0, 9, 1),
          edges: Float32List(9),
        );
      }

      expect(run(0)[4], 1);
      expect(run(1)[4], 2);
      expect(run(0)[0], 1);
      expect(run(0)[1], 0);
    });

    test('детерминизм: два запуска дают одно и то же', () {
      final GeneratedPattern p = _pattern(<String>['1212', '2121', '1212'], <int>[1, 2]);
      Uint16List run() => const PottsLabelSmoother().smooth(
        values: Uint16List.fromList(_cells(p.grid)),
        costs: _flatCosts(p, truth: 1),
        neighbors: CellNeighbors.of(geometry: _rect, columns: 4, rows: 3),
        importance: Float32List(12)..fillRange(0, 12, 1),
        edges: Float32List(12),
      );
      expect(run(), run());
    });
  });

  group('RemoveIslandsStep', () {
    test('одиночные клетки и острова меньше minIsland перекрашиваются в соседний цвет', () {
      final GeneratedPattern p = _pattern(
        <String>['1111', '1211', '1111', '1131'],
        <int>[0xFF0000, 0x00FF00, 0x0000FF],
      );
      final GeneratedPattern out = const RemoveIslandsStep().apply(p, _context(p));
      expect(_cells(out.grid).toSet(), <int>{1});
    });

    test('оттенковая фактура (T66): одиночка близкого оттенка остаётся, чужого тона убирается', () {
      final GeneratedPattern near = _pattern(<String>['111', '121', '111'], <int>[0x808080, 0x858585]);
      expect(_cells(const RemoveIslandsStep(keepToneDeltaE: 5).apply(near, _context(near)).grid).contains(2), isTrue);
      expect(_cells(const RemoveIslandsStep().apply(near, _context(near)).grid).contains(2), isFalse);
      final GeneratedPattern far = _pattern(<String>['111', '121', '111'], <int>[0x808080, 0xFF00FF]);
      expect(_cells(const RemoveIslandsStep(keepToneDeltaE: 5).apply(far, _context(far)).grid).contains(2), isFalse);
    });

    test('клетка под маской «важное» сохраняется', () {
      final GeneratedPattern p = _pattern(<String>['111', '121', '111'], <int>[0xFF0000, 0x00FF00]);
      final GeneratedPattern out = const RemoveIslandsStep().apply(p, _context(p, importance: <int, double>{4: 5}));
      expect(out.grid.at(1, 1), 2);
    });

    test('вес рамки лица (4) сам не защищает: одиночная клетка внутри лица чистится', () {
      final GeneratedPattern p = _pattern(<String>['111', '121', '111'], <int>[0xFF0000, 0x00FF00]);
      final GeneratedPattern out = const RemoveIslandsStep().apply(p, _context(p, importance: <int, double>{4: 4}));
      expect(out.grid.at(1, 1), 1);
    });

    test('сильный край защищает клетку', () {
      final GeneratedPattern p = _pattern(<String>['111', '121', '111'], <int>[0xFF0000, 0x00FF00]);
      final Float32List edges = Float32List(9)..[4] = 50;
      final PatternStepContext c = PatternStepContext(
        geometry: _rect,
        cellImportance: Float32List(9)..fillRange(0, 9, 1),
        cellEdges: edges,
      );
      expect(const RemoveIslandsStep().apply(p, c).grid.at(1, 1), 2);
    });

    test('заметная деталь (T64) защищает клетку, а слабая нет', () {
      final GeneratedPattern p = _pattern(<String>['111', '121', '111'], <int>[0xFF0000, 0x00FF00]);
      PatternStepContext withDetail(double v) => PatternStepContext(
        geometry: _rect,
        cellImportance: Float32List(9)..fillRange(0, 9, 1),
        cellDetail: Float32List(9)..[4] = v,
      );
      expect(const RemoveIslandsStep().apply(p, withDetail(0.6)).grid.at(1, 1), 2);
      expect(const RemoveIslandsStep().apply(p, withDetail(0.3)).grid.at(1, 1), 1);
    });

    test('диагональная линия из клеток, касающихся углами, сохраняется (T64)', () {
      final GeneratedPattern p = _pattern(<String>['2111', '1211', '1121', '1112'], <int>[0xFF0000, 0x00FF00]);
      final GeneratedPattern out = const RemoveIslandsStep(protectDiagonals: true).apply(p, _context(p));
      expect(<int>[for (int i = 0; i < 4; i++) out.grid.at(i, i)], everyElement(2));
    });

    test('диагональная линия без защиты чистится, пара без продолжения чистится и с защитой', () {
      final GeneratedPattern line = _pattern(<String>['2111', '1211', '1121', '1112'], <int>[0xFF0000, 0x00FF00]);
      expect(_cells(const RemoveIslandsStep().apply(line, _context(line)).grid).toSet(), <int>{1});
      final GeneratedPattern p = _pattern(<String>['1111', '1211', '1121', '1111'], <int>[0xFF0000, 0x00FF00]);
      final GeneratedPattern out = const RemoveIslandsStep(protectDiagonals: true).apply(p, _context(p));
      expect(_cells(out.grid).toSet(), <int>{1});
    });

    test('линия шириной в одну клетку длиной 5 сохраняется', () {
      final GeneratedPattern p = _pattern(<String>['1111111', '1222221', '1111111'], <int>[0xFF0000, 0x00FF00]);
      final GeneratedPattern out = const RemoveIslandsStep(minIsland: 6).apply(p, _context(p));
      expect(_cells(out.grid), _cells(p.grid));
    });

    test('толстая область меньше minIsland перекрашивается, при цене выбирается дешёвый сосед', () {
      final GeneratedPattern p = _pattern(<String>['1133', '1123', '1133'], <int>[0xFF0000, 0x00FF00, 0x0000FF]);
      // Одинокая «2» в середине: цвет 3 для неё дешевле цвета 1.
      final Float32List v = Float32List(12 * 3);
      for (int i = 0; i < 12; i++) {
        v[i * 3] = 9;
        v[i * 3 + 1] = 9;
        v[i * 3 + 2] = 9;
      }
      v[6 * 3 + 0] = 8;
      v[6 * 3 + 2] = 1;
      final CellCosts costs = CellCosts(columns: 4, rows: 3, colorCount: 3, values: v);
      final GeneratedPattern out = const RemoveIslandsStep().apply(p, _context(p, costs: costs));
      expect(out.grid.at(2, 1), 3);
    });

    test('учитывает сдвиг рядов peyote: соседство из геометрии', () {
      const GridGeometry peyote = GridGeometry.peyote();
      final GeneratedPattern p = _pattern(<String>['1111', '1121', '1111', '1111'], <int>[0xFF0000, 0x00FF00]);
      final CellNeighbors n = CellNeighbors.of(geometry: peyote, columns: 4, rows: 4);
      // Клетка (2,1) в peyote имеет иных соседей, чем в прямоугольной сетке, но остаётся одинокой.
      expect(countSingleCells(p.grid, peyote), 1);
      expect(n.count(1 * 4 + 2), greaterThan(0));
      final GeneratedPattern out = const RemoveIslandsStep().apply(p, _context(p, geometry: peyote));
      expect(countSingleCells(out.grid, peyote), 0);
    });
  });

  group('MergeColorsStep', () {
    test('близкие цвета с малой площадью сливаются, число цветов не растёт', () {
      final GeneratedPattern p = _pattern(
        <String>[...List<String>.filled(29, '111111'), '111112', '333333'],
        <int>[
          0xCC3333,
          0xCC3636,
          0x3333CC,
        ],
      );
      final GeneratedPattern out = const MergeColorsStep().apply(p, _context(p));
      expect(_cells(out.grid).toSet(), <int>{1, 3});
    });

    test('далёкие цвета не сливаются, даже малые', () {
      final GeneratedPattern p = _pattern(<String>['1111', '1111', '1112'], <int>[0xFFFFFF, 0x000000]);
      expect(_cells(const MergeColorsStep().apply(p, _context(p)).grid), _cells(p.grid));
    });

    test('цвета с большой площадью не сливаются, даже близкие', () {
      final GeneratedPattern p = _pattern(<String>['1122', '1122'], <int>[0xCC3333, 0xCC3636]);
      expect(_cells(const MergeColorsStep().apply(p, _context(p)).grid), _cells(p.grid));
    });
  });

  group('конвейер с предустановкой', () {
    SourceImage noisy() {
      // Однотонный фон с редкими «шумовыми» пятнами другого, но близкого цвета.
      final math.Random random = math.Random(3);
      return painted(80, 80, 0xC03030, <(int, int, int, int, int)>[
        for (int i = 0; i < 40; i++) ...<(int, int, int, int, int)>[
          () {
            final int x = random.nextInt(78);
            final int y = random.nextInt(78);
            return (x, y, x + 2, y + 2, 0xD04040);
          }(),
        ],
      ]);
    }

    ImageToGridRequest request(GenerationPreset? preset, SourceImage image) => ImageToGridSettings(
      maxColors: 6,
      paletteSource: PaletteSource.free,
      preset: preset,
    ).toRequest(image: image);

    test('одиночные клетки: «сбалансированно» убирает минимум вдвое, статистика «было → стало»', () {
      final SourceImage image = painted(80, 80, 0x3060C0, <(int, int, int, int, int)>[
        (0, 0, 40, 80, 0xC03030),
        (10, 10, 13, 13, 0x30C030),
        (50, 50, 53, 53, 0xC0C030),
      ]);
      const ImageToGridPipeline pipeline = ImageToGridPipeline();
      final GeneratedPattern before = pipeline.run(request(null, noisy()));
      final GeneratedPattern after = pipeline.run(request(GenerationPreset.balanced, noisy()));
      expect(after.stats!.singleCells, lessThanOrEqualTo(before.stats!.singleCells));
      final GeneratedPattern pattern = pipeline.run(request(GenerationPreset.balanced, image));
      expect(pattern.stats!.singleCellsBefore, isNotNull);
      expect(pattern.stats!.singleCells, lessThanOrEqualTo(pattern.stats!.singleCellsBefore!));
      expect(pattern.stats!.colorCount, lessThanOrEqualTo(6));
    });

    test('детерминизм по сиду и число цветов не больше заданного во всех предустановках', () {
      final SourceImage image = noisy();
      for (final GenerationPreset preset in GenerationPreset.values) {
        const ImageToGridPipeline pipeline = ImageToGridPipeline();
        final GeneratedPattern a = pipeline.run(request(preset, image));
        final GeneratedPattern b = pipeline.run(request(preset, image));
        expect(_cells(a.grid), _cells(b.grid), reason: '$preset');
        expect(a.palette.length, lessThanOrEqualTo(6), reason: '$preset');
      }
    });

    test('с дизерингом предустановка действует, а дизеринг — последний шаг (T57)', () {
      final ImageToGridRequest r = const ImageToGridSettings(dither: true).toRequest(image: noisy());
      expect(r.usesPixelStages, isTrue);
      expect(r.dither, isFalse);
      expect(r.steps.last, isA<OrderedDitherStep>());
    });

    test('без предустановки с дизерингом остаётся путь T24 с Флойдом — Стейнбергом', () {
      final ImageToGridRequest r = const ImageToGridSettings(
        dither: true,
        preset: null,
      ).toRequest(image: noisy());
      expect(r.usesPixelStages, isFalse);
      expect(r.dither, isTrue);
    });
  });
}

void _extra() {
  test('Поттс: шахматка с равными ценами не дрожит и приходит к одному цвету', () {
    final GeneratedPattern p = _pattern(<String>['1212', '2121', '1212', '2121'], <int>[1, 2]);
    final Uint16List out = const PottsLabelSmoother().smooth(
      values: Uint16List.fromList(_cells(p.grid)),
      costs: CellCosts(columns: 4, rows: 4, colorCount: 2, values: Float32List(32)),
      neighbors: CellNeighbors.of(geometry: _rect, columns: 4, rows: 4),
      importance: Float32List(16)..fillRange(0, 16, 1),
      edges: Float32List(16),
    );
    expect(out.toSet().length, lessThan(2));
  });

  test('refillAccents отдаёт свободное место группе, плохо покрытой палитрой', () {
    final SourceImage image = painted(40, 40, 0x3060C0, <(int, int, int, int, int)>[(0, 0, 20, 40, 0xC03030)]);
    final ImageToGridRequest request = const ImageToGridSettings(
      columns: 20,
      maxColors: 3,
      paletteSource: PaletteSource.free,
    ).toRequest(image: image);
    expect(request.refillFreedColors, isTrue);
    final GeneratedPattern out = const ImageToGridPipeline().run(request);
    expect(out.palette.length, lessThanOrEqualTo(3));
    expect(out.stats!.singleCells, 0);
  });
}
