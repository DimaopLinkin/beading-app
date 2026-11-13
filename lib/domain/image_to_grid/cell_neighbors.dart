import 'dart:typed_data';

import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';

/// Соседи каждой клетки по геометрии (сдвиг рядов пейота и кирпича учтён), посчитанные один раз.
///
/// Нужен стадиям очистки: они обходят соседей десятки тысяч раз, а `GridGeometry.neighbors` каждый раз создаёт список.
final class CellNeighbors {
  CellNeighbors._(this.columns, this.rows, this._starts, this._items);

  factory CellNeighbors.of({required GridGeometry geometry, required int columns, required int rows}) {
    final Int32List starts = Int32List(columns * rows + 1);
    final List<int> items = <int>[];
    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < columns; column++) {
        for (final CellPosition n in geometry.neighbors(
          columns: columns,
          rows: rows,
          cell: CellPosition(column, row),
        )) {
          items.add(n.row * columns + n.column);
        }
        starts[row * columns + column + 1] = items.length;
      }
    }
    return CellNeighbors._(columns, rows, starts, Int32List.fromList(items));
  }

  final int columns;
  final int rows;
  final Int32List _starts;
  final Int32List _items;

  int get cellCount => columns * rows;

  /// Сколько соседей у клетки [cell] (ряд × столбцов + столбец).
  int count(int cell) => _starts[cell + 1] - _starts[cell];

  /// Номер [i]-го соседа клетки [cell] в том же нумеровании.
  int at(int cell, int i) => _items[_starts[cell] + i];
}
