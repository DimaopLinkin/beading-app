import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/materials/bead_estimate.dart';
import 'package:beading/domain/materials/material_estimate.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import '../grid/reading_fixtures.dart';

PatternColor _color(String name, int rgb) => PatternColor(
  rgb: Rgb(rgb >> 16 & 0xFF, rgb >> 8 & 0xFF, rgb & 0xFF),
  name: name,
  components: <CatalogRef>[CatalogRef(brand: 'miyuki', code: name)],
);

PaletteSnapshot _palette(int count) => PaletteSnapshot(
  <PatternColor>[
    _color('A', 0xFF0000),
    _color('B', 0x00FF00),
    _color('C', 0x0000FF),
  ].take(count).toList(),
);

void main() {
  group('BeadEstimator', () {
    test('штуки по цветам совпадают с ручным подсчётом по рисунку станка', () {
      // Ручной подсчёт: A 3+1+6+4 = 14, B 3+4+1 = 8, C 1+1 = 2; всего 24 = 6 × 4.
      final BeadEstimate estimate = BeadEstimator(beadSize: BeadSize.delica11).estimate(loomFixture.grid, _palette(3));

      expect(estimate.lines.map((l) => (l.colorIndex, l.pieces)), <(int, int)>[
        (1, 14),
        (2, 8),
        (3, 2),
      ]);
      expect(estimate.totalPieces, 24);
    });

    test('запас 10% округляется вверх для каждого цвета', () {
      final BeadEstimate estimate = BeadEstimator(beadSize: BeadSize.delica11).estimate(loomFixture.grid, _palette(3));

      // 14 × 1,1 = 15,4 → 16; 8 × 1,1 = 8,8 → 9; 2 × 1,1 = 2,2 → 3.
      expect(estimate.lines.map((l) => l.piecesWithReserve), <int>[16, 9, 3]);
      expect(estimate.totalPiecesWithReserve, 28);
      expect(estimate.reserve, 0.1);
    });

    test('ровное число при запасе не получает лишнюю бусину', () {
      final Grid grid = Grid.fromCells(width: 10, height: 1, cells: List<int>.filled(10, 1));

      final BeadEstimate estimate = BeadEstimator(beadSize: BeadSize.delica11).estimate(grid, _palette(1));

      expect(estimate.lines.single.piecesWithReserve, 11);
    });

    test('граммы по весу бусины размера', () {
      final BeadEstimate estimate = BeadEstimator(
        beadSize: BeadSize.rocaille11,
      ).estimate(loomFixture.grid, _palette(3));

      expect(estimate.lines.first.grams, closeTo(14 * BeadSize.rocaille11.weightGrams, 1e-9));
      expect(estimate.lines.first.gramsWithReserve, closeTo(16 * BeadSize.rocaille11.weightGrams, 1e-9));
      expect(estimate.totalGrams, closeTo(24 * BeadSize.rocaille11.weightGrams, 1e-9));
      expect(estimate.totalGramsWithReserve, closeTo(28 * BeadSize.rocaille11.weightGrams, 1e-9));
    });

    test('запас настраивается, включая ноль', () {
      final BeadEstimate none = BeadEstimator(
        beadSize: BeadSize.delica11,
        reserve: 0,
      ).estimate(loomFixture.grid, _palette(3));
      final BeadEstimate quarter = BeadEstimator(
        beadSize: BeadSize.delica11,
        reserve: 0.25,
      ).estimate(loomFixture.grid, _palette(3));

      expect(none.lines.map((l) => l.piecesWithReserve), <int>[14, 8, 2]);
      expect(quarter.lines.map((l) => l.piecesWithReserve), <int>[18, 10, 3]);
    });

    test('цвета, которых нет в схеме, и пустые ячейки не считаются', () {
      final BeadEstimate estimate = BeadEstimator(
        beadSize: BeadSize.delica11,
      ).estimate(peyoteOddFixture.grid, _palette(3));

      expect(estimate.totalPieces, 11);
      expect(estimate.lines.map((l) => l.colorIndex), <int>[1, 2, 3]);
      final BeadEstimate onlyA = BeadEstimator(beadSize: BeadSize.delica11).estimate(
        Grid.fromCells(width: 2, height: 1, cells: <int>[1, 0]),
        _palette(3),
      );
      expect(onlyA.lines.map((l) => l.colorIndex), <int>[1]);
    });

    test('пустая схема — пустой расход', () {
      final BeadEstimate estimate = BeadEstimator(
        beadSize: BeadSize.delica11,
      ).estimate(Grid.empty(width: 2, height: 2), _palette(3));

      expect(estimate.lines, isEmpty);
      expect(estimate.totalPieces, 0);
      expect(estimate.totalGrams, 0);
    });

    test('цвет схемы вне палитры — ошибка, а не молчаливая недостача', () {
      final BeadEstimator estimator = BeadEstimator(beadSize: BeadSize.delica11);

      expect(() => estimator.estimate(loomFixture.grid, _palette(2)), throwsArgumentError);
    });

    test('запас вне 0–1 отклоняется', () {
      expect(() => BeadEstimator(beadSize: BeadSize.delica11, reserve: -0.1), throwsArgumentError);
      expect(() => BeadEstimator(beadSize: BeadSize.delica11, reserve: 1.5), throwsArgumentError);
      expect(() => BeadEstimator(beadSize: BeadSize.delica11, reserve: double.nan), throwsArgumentError);
    });

    test('реализует общий интерфейс для вышивки', () {
      final MaterialEstimator estimator = BeadEstimator(beadSize: BeadSize.delica11);
      final MaterialEstimate estimate = estimator.estimate(loomFixture.grid, _palette(3));

      expect(estimate.lines.length, 3);
      expect(estimate.lines.first.color.name, 'A');
    });
  });
}
