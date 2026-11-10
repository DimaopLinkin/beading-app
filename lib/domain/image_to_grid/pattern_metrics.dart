import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';

/// Подсчёт «одиночных клеток»: непустых клеток, ни один сосед которых не того же цвета.
///
/// Соседство берётся из [geometry], поэтому сдвиг рядов пейота и кирпичного стежка учтён.
int countSingleCells(Grid grid, GridGeometry geometry) {
  int singles = 0;
  for (int row = 0; row < grid.height; row++) {
    for (int column = 0; column < grid.width; column++) {
      final int value = grid.at(column, row);
      if (value == 0) continue;
      final bool alone = geometry
          .neighbors(columns: grid.width, rows: grid.height, cell: CellPosition(column, row))
          .every((n) => grid.at(n.column, n.row) != value);
      if (alone) singles++;
    }
  }
  return singles;
}
