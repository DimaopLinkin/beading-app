import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid/reading_order.dart';
import 'package:beading/domain/grid/word_chart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reading_fixtures.dart';

List<String> _chart(ReadingFixture fixture, GridGeometry geometry, [ReadingStart start = ReadingStart.topLeft]) {
  final ReadingOrder order = ReadingOrder.of(geometry, columns: fixture.width, rows: fixture.height, start: start);
  return WordChart.build(fixture.grid, order).map((r) => describeRuns(r.runs)).toList();
}

void main() {
  group('эталонные схемы (серии выписаны с рисунка вручную)', () {
    test('станок, начало слева сверху', () {
      expect(_chart(loomFixture, const GridGeometry.rectangular()), <String>['2A 3B 1A', '1A 4B 1C', '6A', '1C 4A 1B']);
    });

    test('станок, начало справа снизу: ряды снизу вверх, справа налево', () {
      expect(_chart(loomFixture, const GridGeometry.rectangular(), ReadingStart.bottomRight), <String>[
        '1B 4A 1C',
        '6A',
        '1C 4B 1A',
        '1A 3B 2A',
      ]);
    });

    test('кирпичный стежок: ряды читаются по очереди туда и обратно', () {
      expect(_chart(brickFixture, const GridGeometry.brick()), <String>[
        '1A 1B 1A 1B 1A',
        '3A 2B',
        '2A 2B 1C',
        '1B 1A 3C',
      ]);
    });

    test('мозаика чётная: первый ряд — два столбца зигзагом', () {
      expect(_chart(peyoteEvenFixture, const GridGeometry.peyote()), <String>['2A 1B 1A 2C', '1A 2B', '1B 2A']);
    });

    test('мозаика чётная, начало справа', () {
      expect(_chart(peyoteEvenFixture, const GridGeometry.peyote(), ReadingStart.topRight), <String>[
        '3B 3A',
        '1C 2A',
        '1A 1B 1C',
      ]);
    });

    test('мозаика чётная, начало слева снизу', () {
      expect(_chart(peyoteEvenFixture, const GridGeometry.peyote(), ReadingStart.bottomLeft), <String>[
        '2C 1A 1B 2A',
        '2B 1A',
        '2A 1B',
      ]);
    });

    test('мозаика нечётная: пустая ячейка не бусина и рвёт серию', () {
      expect(_chart(peyoteOddFixture, const GridGeometry.peyote()), <String>['2A 1B 1A 1C', '1A 2B', '1B 2A']);
    });
  });

  group('склейка серий', () {
    test('подряд идущие одного цвета склеиваются, разных — нет', () {
      final Grid grid = Grid.fromCells(width: 6, height: 1, cells: <int>[1, 1, 1, 2, 2, 1]);
      final ReadingOrder order = ReadingOrder.of(const GridGeometry.rectangular(), columns: 6, rows: 1);

      expect(WordChart.forRow(grid, order.row(0)), const <WordRun>[WordRun(1, 3), WordRun(2, 2), WordRun(1, 1)]);
    });

    test('серия не переходит через пустую ячейку', () {
      final Grid grid = Grid.fromCells(width: 5, height: 1, cells: <int>[1, 1, 0, 1, 0]);
      final ReadingOrder order = ReadingOrder.of(const GridGeometry.rectangular(), columns: 5, rows: 1);

      expect(WordChart.forRow(grid, order.row(0)), const <WordRun>[WordRun(1, 2), WordRun(1, 1)]);
    });

    test('пустой ряд — пустой word chart', () {
      final Grid grid = Grid.empty(width: 3, height: 1);
      final ReadingOrder order = ReadingOrder.of(const GridGeometry.rectangular(), columns: 3, rows: 1);

      expect(WordChart.forRow(grid, order.row(0)), isEmpty);
    });

    test('в каждом ряду станка шесть бусин', () {
      final List<WordChartRow> chart = WordChart.build(
        loomFixture.grid,
        ReadingOrder.of(const GridGeometry.rectangular(), columns: 6, rows: 4),
      );

      expect(chart.map((r) => r.beadCount), everyElement(6));
      expect(chart.first.direction, RowDirection.right);
    });

    test('размер сетки и порядка должен совпадать', () {
      final ReadingOrder order = ReadingOrder.of(const GridGeometry.rectangular(), columns: 3, rows: 3);

      expect(() => WordChart.build(loomFixture.grid, order), throwsArgumentError);
    });
  });
}
