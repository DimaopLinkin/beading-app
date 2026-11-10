import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/pattern_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

Grid _grid(int width, List<int> cells) => Grid.fromCells(width: width, height: cells.length ~/ width, cells: cells);

void main() {
  group('countSingleCells', () {
    test('клетка без соседа своего цвета — одиночная', () {
      final Grid grid = _grid(3, <int>[1, 1, 1, 1, 2, 1, 1, 1, 1]);
      expect(countSingleCells(grid, const GridGeometry.rectangular()), 1);
    });

    test('пара клеток одного цвета не одиночные, по диагонали соседство не считается', () {
      final Grid grid = _grid(3, <int>[1, 1, 2, 3, 3, 2, 4, 5, 5]);
      expect(countSingleCells(grid, const GridGeometry.rectangular()), 1);
      final Grid diagonal = _grid(2, <int>[1, 2, 2, 1]);
      expect(countSingleCells(diagonal, const GridGeometry.rectangular()), 4);
    });

    test('пустые клетки не считаются и не соседи', () {
      final Grid grid = _grid(3, <int>[0, 1, 0, 0, 0, 0]);
      expect(countSingleCells(grid, const GridGeometry.rectangular()), 1);
    });

    test('в пейоте соседство со сдвигом: клетки (1, 0) и (0, 1) касаются', () {
      final Grid grid = _grid(2, <int>[1, 2, 2, 1]);
      expect(countSingleCells(grid, const GridGeometry.rectangular()), 4);
      expect(countSingleCells(grid, const GridGeometry.peyote()), 2);
    });
  });
}
