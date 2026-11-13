import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid/reading_order.dart';
import 'package:flutter_test/flutter_test.dart';

ReadingOrder _order(GridGeometry geometry, int columns, int rows, [ReadingStart start = ReadingStart.topLeft]) =>
    ReadingOrder.of(geometry, columns: columns, rows: rows, start: start);

List<RowDirection> _directions(ReadingOrder order) => order.allRows.map((r) => r.direction).toList();

void main() {
  largeSchemes();
  group('станок', () {
    const GridGeometry geometry = GridGeometry.rectangular();

    test('ряды сверху вниз, направление у всех одно', () {
      final ReadingOrder order = _order(geometry, 3, 3);

      expect(order.rowCount, 3);
      expect(_directions(order), everyElement(RowDirection.right));
      expect(order.row(0).cells, <CellPosition>[
        const CellPosition(0, 0),
        const CellPosition(1, 0),
        const CellPosition(2, 0),
      ]);
      expect(order.row(2).cells.first, const CellPosition(0, 2));
    });

    test('начало справа снизу: нижний ряд первый, ячейки справа налево', () {
      final ReadingOrder order = _order(geometry, 3, 2, ReadingStart.bottomRight);

      expect(order.row(0).cells, <CellPosition>[
        const CellPosition(2, 1),
        const CellPosition(1, 1),
        const CellPosition(0, 1),
      ]);
      expect(order.row(1).cells.first, const CellPosition(2, 0));
      expect(_directions(order), everyElement(RowDirection.left));
    });
  });

  group('кирпичный стежок', () {
    const GridGeometry geometry = GridGeometry.brick();

    test('направление чередуется', () {
      final ReadingOrder order = _order(geometry, 3, 4);

      expect(_directions(order), <RowDirection>[
        RowDirection.right,
        RowDirection.left,
        RowDirection.right,
        RowDirection.left,
      ]);
      expect(order.row(1).cells.first, const CellPosition(2, 1));
    });

    test('начало справа сверху: первый ряд справа налево', () {
      final ReadingOrder order = _order(geometry, 3, 2, ReadingStart.topRight);

      expect(_directions(order), <RowDirection>[RowDirection.left, RowDirection.right]);
      expect(order.row(0).cells.first, const CellPosition(2, 0));
    });
  });

  group('мозаика/пейот', () {
    const GridGeometry geometry = GridGeometry.peyote();

    test('первый ряд плетения — два столбца зигзагом, рядов на один меньше столбцов', () {
      final ReadingOrder order = _order(geometry, 4, 3);

      expect(order.rowCount, 3);
      expect(order.row(0).cells, <CellPosition>[
        const CellPosition(0, 0),
        const CellPosition(1, 0),
        const CellPosition(0, 1),
        const CellPosition(1, 1),
        const CellPosition(0, 2),
        const CellPosition(1, 2),
      ]);
    });

    test('направление чередуется, второй ряд — третий столбец вверх', () {
      final ReadingOrder order = _order(geometry, 4, 3);

      expect(_directions(order), <RowDirection>[RowDirection.down, RowDirection.up, RowDirection.down]);
      expect(order.row(1).cells, <CellPosition>[
        const CellPosition(2, 2),
        const CellPosition(2, 1),
        const CellPosition(2, 0),
      ]);
    });

    test('начало снизу: первый проход вверх, сначала нижняя бусина второго столбца', () {
      final ReadingOrder order = _order(geometry, 4, 2, ReadingStart.bottomLeft);

      expect(order.row(0).direction, RowDirection.up);
      expect(order.row(0).cells, <CellPosition>[
        const CellPosition(1, 1),
        const CellPosition(0, 1),
        const CellPosition(1, 0),
        const CellPosition(0, 0),
      ]);
    });

    test('начало справа: работа идёт с последнего столбца', () {
      final ReadingOrder order = _order(geometry, 4, 2, ReadingStart.topRight);

      expect(order.row(0).cells.first, const CellPosition(2, 0));
      expect(order.row(1).cells.first, const CellPosition(1, 1));
      expect(order.row(2).cells.first, const CellPosition(0, 0));
    });

    test('один столбец — один ряд', () {
      final ReadingOrder order = _order(geometry, 1, 3);

      expect(order.rowCount, 1);
      expect(order.row(0).cells.length, 3);
    });

    test('2-drop: каждый столбец — отдельный ряд', () {
      final ReadingOrder order = _order(const GridGeometry.peyote(drop: 2), 4, 3);

      expect(order.rowCount, 4);
      expect(order.row(0).cells, everyElement(predicate<CellPosition>((c) => c.column == 0)));
    });
  });

  group('любая геометрия', () {
    final Map<String, GridGeometry> geometries = <String, GridGeometry>{
      'станок': const GridGeometry.rectangular(),
      'кирпич': const GridGeometry.brick(),
      'пейот': const GridGeometry.peyote(),
      '2-drop': const GridGeometry.peyote(drop: 2),
    };

    for (final MapEntry<String, GridGeometry> g in geometries.entries) {
      for (final ReadingStart start in ReadingStart.values) {
        test('${g.key}, ${start.name}: каждая ячейка ровно один раз', () {
          for (final (int columns, int rows) in <(int, int)>[(1, 1), (1, 4), (5, 1), (5, 4), (6, 7)]) {
            final List<CellPosition> all = _order(g.value, columns, rows, start).cells.toList();

            expect(all.length, columns * rows, reason: '$columns × $rows');
            expect(all.toSet().length, columns * rows, reason: '$columns × $rows');
          }
        });
      }
    }

    test('пустая схема и неверный номер ряда', () {
      expect(() => _order(const GridGeometry.rectangular(), 0, 3), throwsArgumentError);
      expect(() => _order(const GridGeometry.rectangular(), 3, 3).row(3), throwsRangeError);
    });
  });
}

void largeSchemes() {
  test('схема 4096×4096 не обходится целиком', () {
    final ReadingOrder order = ReadingOrder.of(const GridGeometry.peyote(), columns: 4096, rows: 4096);

    expect(order.rowCount, 4095);
    expect(order.row(0).cells.length, 8192);
    expect(order.row(4094).cells.length, 4096);
  });

  test('мозаика, начало справа снизу: первый проход вверх, ряды с последнего столбца', () {
    final ReadingOrder order = ReadingOrder.of(
      const GridGeometry.peyote(),
      columns: 5,
      rows: 2,
      start: ReadingStart.bottomRight,
    );

    expect(order.row(0).direction, RowDirection.up);
    expect(order.row(0).cells.first, const CellPosition(3, 1));
    expect(order.row(1).cells.first, const CellPosition(2, 0));
  });

  test('станок и кирпич: оставшиеся углы', () {
    final ReadingOrder loom = ReadingOrder.of(
      const GridGeometry.rectangular(),
      columns: 2,
      rows: 2,
      start: ReadingStart.topRight,
    );
    final ReadingOrder brick = ReadingOrder.of(
      const GridGeometry.brick(),
      columns: 2,
      rows: 2,
      start: ReadingStart.bottomLeft,
    );

    expect(loom.row(0).cells.first, const CellPosition(1, 0));
    expect(brick.row(0).cells.first, const CellPosition(0, 1));
    expect(brick.row(1).cells.first, const CellPosition(1, 0));
  });

  group('длина ряда и равенство', () {
    test('maxRowLength: станок и кирпич — ширина, пейот — высота (первый ряд — два столбца разом)', () {
      expect(ReadingOrder.of(const GridGeometry.rectangular(), columns: 5, rows: 3).maxRowLength, 5);
      expect(ReadingOrder.of(const GridGeometry.brick(), columns: 5, rows: 3).maxRowLength, 5);
      expect(ReadingOrder.of(const GridGeometry.peyote(), columns: 5, rows: 3).maxRowLength, 6);
      expect(ReadingOrder.of(const GridGeometry.peyote(), columns: 1, rows: 3).maxRowLength, 3);
      expect(ReadingOrder.of(const GridGeometry.peyote(drop: 2), columns: 5, rows: 3).maxRowLength, 3);
    });

    test('порядок равен по геометрии, размеру и началу', () {
      final ReadingOrder a = ReadingOrder.of(const GridGeometry.brick(), columns: 5, rows: 3);
      expect(a, ReadingOrder.of(const GridGeometry.brick(), columns: 5, rows: 3));
      expect(
        a,
        isNot(ReadingOrder.of(const GridGeometry.brick(), columns: 5, rows: 3, start: ReadingStart.bottomLeft)),
      );
      expect(a, isNot(ReadingOrder.of(const GridGeometry.rectangular(), columns: 5, rows: 3)));
    });
  });
}
