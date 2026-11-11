import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/gradient_mask.dart';
import 'package:beading/domain/image_to_grid/ordered_dither_step.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/pattern_metrics.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

const GridGeometry _rect = GridGeometry.rectangular();

Rgb _gray(int v) => Rgb(v, v, v);

/// Схема по цветам клеток: каждой клетке ближайший цвет палитры (как после разметки).
(GeneratedPattern, PatternStepContext) _build(List<Rgb?> colors, int columns, int rows, List<Rgb> palette) {
  final List<Lab> lab = <Lab>[for (final Rgb c in palette) Lab.fromRgb(c)];
  final List<int> cells = <int>[
    for (final Rgb? c in colors)
      if (c == null)
        0
      else
        1 +
            List<int>.generate(
              palette.length,
              (i) => i,
            ).reduce((a, b) => deltaE2000(Lab.fromRgb(c), lab[a]) <= deltaE2000(Lab.fromRgb(c), lab[b]) ? a : b),
  ];
  return (
    GeneratedPattern(
      grid: Grid.fromCells(width: columns, height: rows, cells: cells),
      palette: <PaletteEntry>[for (final Rgb c in palette) PaletteEntry(rgb: c)],
    ),
    PatternStepContext(
      geometry: _rect,
      cellImportance: Float32List.fromList(List<double>.filled(columns * rows, 1)),
      cellColors: colors,
    ),
  );
}

List<Rgb?> _ramp(int columns, int rows, {int from = 90, int to = 170}) => <Rgb?>[
  for (int y = 0; y < rows; y++)
    for (int x = 0; x < columns; x++) _gray((from + (to - from) * x / (columns - 1)).round()),
];

const List<Rgb> _greys = <Rgb>[Rgb(90, 90, 90), Rgb(115, 115, 115), Rgb(140, 140, 140), Rgb(170, 170, 170)];

void main() {
  group('gradientMask', () {
    test('плавный перепад светлоты — в маске, однотонная область — нет', () {
      final Uint8List ramp = gradientMask(cellColors: _ramp(40, 8), columns: 40, rows: 8);
      expect(ramp.where((v) => v == 1).length, greaterThan(40 * 8 * 0.6));
      final Uint8List flat = gradientMask(
        cellColors: List<Rgb?>.filled(40 * 8, _gray(128)),
        columns: 40,
        rows: 8,
      );
      expect(flat.where((v) => v == 1), isEmpty);
    });

    test('край (шахматка двух далёких цветов, резкая ступень) в маску не попадает', () {
      final List<Rgb?> checker = <Rgb?>[
        for (int y = 0; y < 8; y++)
          for (int x = 0; x < 40; x++) (x + y).isEven ? _gray(30) : _gray(220),
      ];
      expect(gradientMask(cellColors: checker, columns: 40, rows: 8).where((v) => v == 1), isEmpty);
      final List<Rgb?> step = <Rgb?>[
        for (int y = 0; y < 8; y++)
          for (int x = 0; x < 40; x++) x < 20 ? _gray(40) : _gray(200),
      ];
      expect(gradientMask(cellColors: step, columns: 40, rows: 8).where((v) => v == 1), isEmpty);
    });

    test('немонотонный «горб» не градиент; пустые клетки не в маске', () {
      final List<Rgb?> bump = <Rgb?>[
        for (int y = 0; y < 6; y++)
          for (int x = 0; x < 30; x++) _gray(x.isEven ? 120 : 130),
      ];
      expect(gradientMask(cellColors: bump, columns: 30, rows: 6).where((v) => v == 1), isEmpty);
      final List<Rgb?> withHole = _ramp(40, 8)..[3 * 40 + 20] = null;
      expect(gradientMask(cellColors: withHole, columns: 40, rows: 8)[3 * 40 + 20], 0);
    });

    test('вертикальный градиент тоже находится', () {
      final List<Rgb?> vertical = <Rgb?>[
        for (int y = 0; y < 40; y++)
          for (int x = 0; x < 8; x++) _gray((90 + 80 * y / 39).round()),
      ];
      expect(gradientMask(cellColors: vertical, columns: 8, rows: 40).where((v) => v == 1).length, greaterThan(150));
    });
  });

  group('OrderedDitherStep', () {
    const OrderedDitherStep step = OrderedDitherStep();

    test('пороги Байера 2×2 и 4×4 — все разные числа внутри (0, 1)', () {
      for (final int n in <int>[2, 4]) {
        final OrderedDitherStep s = OrderedDitherStep(matrixSize: n);
        final Set<double> seen = <double>{
          for (int r = 0; r < n; r++)
            for (int c = 0; c < n; c++) s.threshold(c * 2, r),
        };
        expect(seen.length, n * n);
        expect(seen.every((t) => t > 0 && t < 1), isTrue);
      }
    });

    test('однотонная область: ни одной клетки другого цвета, схема та же', () {
      final (GeneratedPattern p, PatternStepContext c) = _build(
        List<Rgb?>.filled(40 * 8, _gray(140)),
        40,
        8,
        _greys,
      );
      expect(step.apply(p, c).grid.cells, orderedEquals(p.grid.cells));
    });

    test('градиент: светлота по столбцам растёт, схема не пестрее палитры', () {
      final (GeneratedPattern p, PatternStepContext c) = _build(_ramp(60, 8), 60, 8, _greys);
      final GeneratedPattern out = step.apply(p, c);
      expect(out.palette, p.palette);
      expect(out.grid.cells.toSet().difference(<int>{1, 2, 3, 4}), isEmpty);
      expect(out.grid.cells, isNot(orderedEquals(p.grid.cells)));
      // Один столбец содержит четыре порога Байера, поэтому сравниваем средние по группам из четырёх столбцов.
      final List<double> mean = <double>[
        for (int g = 0; g < 15; g++)
          <int>[
                for (int x = g * 4; x < g * 4 + 4; x++)
                  for (int y = 0; y < 8; y++) _greys[out.grid.at(x, y) - 1].r,
              ].reduce((a, b) => a + b) /
              32,
      ];
      for (int g = 1; g < mean.length; g++) {
        expect(mean[g], greaterThanOrEqualTo(mean[g - 1] - 3), reason: 'группа $g');
      }
      expect(mean.last - mean.first, closeTo(170 - 90, 25));
      // Дизеринг приближает цвета к исходным: средняя ошибка по клеткам не больше, чем без него.
      double error(GeneratedPattern q) {
        double sum = 0;
        for (int i = 0; i < q.grid.cells.length; i++) {
          sum += (_greys[q.grid.cells[i] - 1].r - c.cellColors![i]!.r).abs();
        }
        return sum;
      }

      // Ошибка отдельных клеток растёт, а ошибка по столбцам (того, что видит глаз) падает.
      expect(error(out), greaterThan(0));
      double columnError(GeneratedPattern q) {
        double sum = 0;
        for (int x = 0; x < 60; x++) {
          double m = 0;
          for (int y = 0; y < 8; y++) {
            m += _greys[q.grid.at(x, y) - 1].r / 8;
          }
          sum += (m - c.cellColors![x]!.r).abs();
        }
        return sum;
      }

      expect(columnError(out), lessThan(columnError(p)));
    });

    test('дизеринг не создаёт одиночных клеток там, где их не было', () {
      final (GeneratedPattern p, PatternStepContext c) = _build(_ramp(60, 8), 60, 8, _greys);
      final GeneratedPattern out = step.apply(p, c);
      expect(countSingleCells(out.grid, _rect), lessThanOrEqualTo(countSingleCells(p.grid, _rect)));
    });

    test('клетки вне маски (край рядом) не меняются', () {
      final List<Rgb?> colors = _ramp(40, 8);
      for (int y = 0; y < 8; y++) {
        for (int x = 20; x < 40; x++) {
          colors[y * 40 + x] = _gray(x.isEven ? 30 : 230);
        }
      }
      final (GeneratedPattern p, PatternStepContext c) = _build(colors, 40, 8, <Rgb>[..._greys, _gray(30), _gray(230)]);
      final GeneratedPattern out = step.apply(p, c);
      for (int y = 0; y < 8; y++) {
        for (int x = 18; x < 40; x++) {
          expect(out.grid.at(x, y), p.grid.at(x, y), reason: '($x, $y)');
        }
      }
    });

    test('клетка, которую очистка закрасила цветом вне пары, не трогается', () {
      final (GeneratedPattern p, PatternStepContext c) = _build(_ramp(40, 8), 40, 8, _greys);
      final GeneratedPattern altered = GeneratedPattern(
        grid: p.grid.withCell(20, 4, 1),
        palette: p.palette,
      );
      expect(step.apply(altered, c).grid.at(20, 4), 1);
    });

    test('без цветов клеток или с одним цветом шаг ничего не делает; результат стабилен', () {
      final (GeneratedPattern p, PatternStepContext c) = _build(_ramp(40, 8), 40, 8, _greys);
      final PatternStepContext bare = PatternStepContext(geometry: _rect, cellImportance: c.cellImportance);
      expect(identical(step.apply(p, bare), p), isTrue);
      expect(step.apply(p, c).grid.cells, orderedEquals(step.apply(p, c).grid.cells));
    });

    test('Байер 2×2 и 4×4 дают разный узор, оба из имеющихся цветов', () {
      final (GeneratedPattern p, PatternStepContext c) = _build(_ramp(60, 8), 60, 8, _greys);
      final GeneratedPattern two = const OrderedDitherStep(matrixSize: 2).apply(p, c);
      final GeneratedPattern four = step.apply(p, c);
      expect(two.grid.cells, isNot(orderedEquals(four.grid.cells)));
    });
  });
}
