import 'package:beading/domain/grid/cell_position.dart';

/// Ячейки на отрезке от [from] до [to] включительно (Брезенхем в индексах ячеек).
///
/// Мазок кистью соединяет соседние касания этим отрезком, чтобы быстрое движение пальца не оставляло пропусков.
/// Первая ячейка — [from], последняя — [to].
List<CellPosition> cellLine(CellPosition from, CellPosition to) {
  final List<CellPosition> cells = <CellPosition>[];
  int x = from.column;
  int y = from.row;
  final int dx = (to.column - x).abs();
  final int dy = -(to.row - y).abs();
  final int sx = x < to.column ? 1 : -1;
  final int sy = y < to.row ? 1 : -1;
  int error = dx + dy;
  while (true) {
    cells.add(CellPosition(x, y));
    if (x == to.column && y == to.row) {
      return cells;
    }
    final int doubled = 2 * error;
    if (doubled >= dy) {
      error += dy;
      x += sx;
    }
    if (doubled <= dx) {
      error += dx;
      y += sy;
    }
  }
}
