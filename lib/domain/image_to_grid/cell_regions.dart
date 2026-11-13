import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid/mm.dart';

/// Прямоугольник рабочих пикселей каждой клетки: геометрия «клетка → участок картинки», как в CellSampler.
///
/// Сдвиг рядов пейота и кирпичного стежка учитывается через центр клетки в миллиметрах. Границы округляются так,
/// что соседние клетки одного ряда стыкуются без щелей и наложений.
final class CellRegions {
  CellRegions._(this.columns, this.rows, this._rects);

  factory CellRegions.forGrid({
    required GridGeometry geometry,
    required CellMetrics metrics,
    required int columns,
    required int rows,
    required int imageWidth,
    required int imageHeight,
  }) {
    final MmSize extent = geometry.extent(metrics, columns: columns, rows: rows);
    final MmSize cell = geometry.cellSize(metrics);
    final double scaleX = imageWidth / extent.width;
    final double scaleY = imageHeight / extent.height;
    int snap(double v) => ((v * 1000).round() / 1000).round();
    final Int32List rects = Int32List(columns * rows * 4);
    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < columns; column++) {
        final MmPoint c = geometry.cellCenter(metrics, CellPosition(column, row));
        int x0 = snap((c.x - cell.width / 2) * scaleX).clamp(0, imageWidth - 1);
        int y0 = snap((c.y - cell.height / 2) * scaleY).clamp(0, imageHeight - 1);
        final int x1 = math.max(x0 + 1, snap((c.x + cell.width / 2) * scaleX)).clamp(1, imageWidth);
        final int y1 = math.max(y0 + 1, snap((c.y + cell.height / 2) * scaleY)).clamp(1, imageHeight);
        x0 = math.min(x0, x1 - 1);
        y0 = math.min(y0, y1 - 1);
        final int i = (row * columns + column) * 4;
        rects[i] = x0;
        rects[i + 1] = y0;
        rects[i + 2] = x1;
        rects[i + 3] = y1;
      }
    }
    return CellRegions._(columns, rows, rects);
  }

  final int columns;
  final int rows;
  final Int32List _rects;

  /// Левая граница (включительно) клетки [cell].
  int left(int cell) => _rects[cell * 4];
  int top(int cell) => _rects[cell * 4 + 1];

  /// Правая граница (не включительно).
  int right(int cell) => _rects[cell * 4 + 2];
  int bottom(int cell) => _rects[cell * 4 + 3];
}
