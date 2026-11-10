import 'dart:math' as math;
import 'dart:ui';

import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/cell_range.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid/mm.dart';

/// Система координат схемы на экране («сцена»): миллиметры геометрии, умноженные на [pxPerMm].
///
/// Чистый класс без виджетов: им пользуются и рисование, и попадание касания в ячейку, поэтому оба видят одну и ту же
/// раскладку. Зум и сдвиг — это преобразование сцены в экран, оно сюда не входит.
final class GridScene {
  GridScene({
    required this.geometry,
    required this.metrics,
    required this.columns,
    required this.rows,
    double smallestCellPx = defaultSmallestCellPx,
  }) : pxPerMm = smallestCellPx / math.min(geometry.cellSize(metrics).width, geometry.cellSize(metrics).height) {
    final MmSize cell = geometry.cellSize(metrics);
    cellSize = Size(cell.width * pxPerMm, cell.height * pxPerMm);
    final MmSize extent = geometry.extent(metrics, columns: columns, rows: rows);
    size = Size(extent.width * pxPerMm, extent.height * pxPerMm);
  }

  /// Меньшая сторона ячейки при зуме 1×, логических пикселей.
  static const double defaultSmallestCellPx = 22;

  final GridGeometry geometry;
  final CellMetrics metrics;
  final int columns;
  final int rows;

  /// Сколько пикселей сцены в миллиметре.
  final double pxPerMm;

  /// Размер ячейки в сцене.
  late final Size cellSize;

  /// Размер всей схемы в сцене.
  late final Size size;

  /// Прямоугольник ячейки.
  Rect cellRect(CellPosition cell) {
    final MmPoint center = geometry.cellCenter(metrics, cell);
    return Rect.fromCenter(
      center: Offset(center.x * pxPerMm, center.y * pxPerMm),
      width: cellSize.width,
      height: cellSize.height,
    );
  }

  /// Ячейка под точкой сцены или `null`.
  CellPosition? cellAt(Offset point) => geometry.cellAt(
    metrics,
    columns: columns,
    rows: rows,
    point: MmPoint(point.dx / pxPerMm, point.dy / pxPerMm),
  );

  /// Ячейки, которые могут попасть в прямоугольник сцены.
  CellRange visibleCells(Rect area) => geometry.visibleCells(
    metrics,
    columns: columns,
    rows: rows,
    left: area.left / pxPerMm,
    top: area.top / pxPerMm,
    right: area.right / pxPerMm,
    bottom: area.bottom / pxPerMm,
  );

  /// Охватывающий прямоугольник ряда (в пейоте и кирпиче ряд ступенчатый, прямоугольник покрывает его целиком).
  Rect rowBounds(int row) {
    Rect bounds = cellRect(CellPosition(0, row));
    // Достаточно первых ячеек: сдвиг геометрий периодичен, а крайние ячейки ряда дают границы по другой оси.
    final int probe = math.min(columns, 4);
    for (int column = 1; column < probe; column++) {
      bounds = bounds.expandToInclude(cellRect(CellPosition(column, row)));
    }
    return bounds.expandToInclude(cellRect(CellPosition(columns - 1, row)));
  }
}
