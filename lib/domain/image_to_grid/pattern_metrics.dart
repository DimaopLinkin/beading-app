import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/palette/lab.dart';

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

/// Светлота схемы относительно фото (T65): разброс и корреляция по рабочим пикселям.
final class LightnessStructure {
  const LightnessStructure({required this.contrast, required this.correlation});

  /// Разброс светлоты схемы к разбросу светлоты фото: 1 — столько же, меньше — схема «выцвела».
  final double contrast;

  /// Корреляция светлоты схемы со светлотой фото: 1 — все света и тени на своих местах.
  final double correlation;
}

/// Считает [LightnessStructure] по рабочим пикселям [lightness] ([workWidth] в ряду), разбитым на клетки [regions].
/// Пустые клетки не учитываются. `null`, если у фото нет разброса светлоты или считать нечего.
LightnessStructure? lightnessStructure({
  required Float32List lightness,
  required int workWidth,
  required CellRegions regions,
  required Grid grid,
  required List<PaletteEntry> palette,
}) {
  final List<double> paletteL = <double>[for (final PaletteEntry e in palette) Lab.fromRgb(e.rgb).l];
  double sx = 0;
  double sy = 0;
  double sxx = 0;
  double syy = 0;
  double sxy = 0;
  int n = 0;
  for (int cell = 0; cell < regions.columns * regions.rows; cell++) {
    final int value = grid.at(cell % regions.columns, cell ~/ regions.columns);
    if (value == 0) continue;
    final double y = paletteL[value - 1];
    for (int yy = regions.top(cell); yy < regions.bottom(cell); yy++) {
      for (int xx = regions.left(cell); xx < regions.right(cell); xx++) {
        final double x = lightness[yy * workWidth + xx];
        sx += x;
        sy += y;
        sxx += x * x;
        syy += y * y;
        sxy += x * y;
        n++;
      }
    }
  }
  if (n == 0) return null;
  final double vx = sxx / n - (sx / n) * (sx / n);
  final double vy = syy / n - (sy / n) * (sy / n);
  if (vx < 1e-3) return null;
  final double cov = sxy / n - (sx / n) * (sy / n);
  return LightnessStructure(
    contrast: math.sqrt(math.max(vy, 0) / vx),
    correlation: vy < 1e-6 ? 0 : cov / math.sqrt(vx * vy),
  );
}
