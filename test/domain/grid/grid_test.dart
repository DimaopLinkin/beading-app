import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Grid', () {
    test('пустая сетка заполнена нулями', () {
      final Grid grid = Grid.empty(width: 3, height: 2);

      expect(grid.width, 3);
      expect(grid.height, 2);
      expect(grid.cells, everyElement(0));
      expect(grid.cells.length, 6);
    });

    test('сетка 1×1 допустима', () {
      final Grid grid = Grid.empty(width: 1, height: 1);

      expect(grid.at(0, 0), 0);
    });

    test('at читает по столбцу и ряду', () {
      final Grid grid = Grid.fromCells(width: 3, height: 2, cells: <int>[1, 2, 3, 4, 5, 6]);

      expect(grid.at(0, 0), 1);
      expect(grid.at(2, 0), 3);
      expect(grid.at(0, 1), 4);
      expect(grid.at(2, 1), 6);
    });

    test('withCell возвращает копию, исходная сетка не меняется', () {
      final Grid original = Grid.empty(width: 2, height: 2);

      final Grid changed = original.withCell(1, 0, 7);

      expect(changed.at(1, 0), 7);
      expect(original.at(1, 0), 0);
      expect(changed, isNot(original));
    });

    test('конструктор копирует входной список', () {
      final Uint16List source = Uint16List.fromList(<int>[1, 2, 3, 4]);
      final Grid grid = Grid.fromCells(width: 2, height: 2, cells: source);

      source[0] = 99;

      expect(grid.at(0, 0), 1);
    });

    test('cells нельзя изменить снаружи', () {
      final Grid grid = Grid.empty(width: 2, height: 2);

      expect(() => grid.cells[0] = 1, throwsUnsupportedError);
    });

    test('равенство и hashCode по размеру и содержимому', () {
      final Grid a = Grid.fromCells(width: 2, height: 2, cells: <int>[1, 2, 3, 4]);
      final Grid b = Grid.fromCells(width: 2, height: 2, cells: <int>[1, 2, 3, 4]);
      final Grid differentCell = Grid.fromCells(width: 2, height: 2, cells: <int>[1, 2, 3, 5]);
      final Grid differentShape = Grid.fromCells(width: 4, height: 1, cells: <int>[1, 2, 3, 4]);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(differentCell));
      expect(a, isNot(differentShape));
    });

    test('отказывает на неверных размерах и данных', () {
      expect(() => Grid.empty(width: 0, height: 1), throwsArgumentError);
      expect(() => Grid.empty(width: 1, height: 0), throwsArgumentError);
      expect(() => Grid.empty(width: Grid.maxSide + 1, height: 1), throwsArgumentError);
      expect(() => Grid.fromCells(width: 2, height: 2, cells: <int>[1, 2, 3]), throwsArgumentError);
      expect(() => Grid.fromCells(width: 1, height: 1, cells: <int>[65536]), throwsArgumentError);
      expect(() => Grid.fromCells(width: 1, height: 1, cells: <int>[-1]), throwsArgumentError);
    });

    test('at и withCell вне границ бросают RangeError', () {
      final Grid grid = Grid.empty(width: 2, height: 2);

      expect(() => grid.at(2, 0), throwsRangeError);
      expect(() => grid.at(0, -1), throwsRangeError);
      expect(() => grid.withCell(0, 2, 1), throwsRangeError);
    });

    test('withCell отказывает на индексе палитры вне Uint16', () {
      final Grid grid = Grid.empty(width: 2, height: 2);

      expect(() => grid.withCell(0, 0, 65536), throwsArgumentError);
    });
  });
}
