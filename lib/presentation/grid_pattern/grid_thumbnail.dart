import 'dart:math' as math;

import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:flutter/cupertino.dart';

/// Миниатюра схемы для карточки в библиотеке: ячейки цветными прямоугольниками, без линий и знаков.
/// Вписывается в отданное место с сохранением пропорций схемы.
class GridThumbnail extends StatelessWidget {
  const GridThumbnail({
    required this.grid,
    required this.palette,
    required this.geometry,
    required this.metrics,
    super.key,
  });

  final Grid grid;
  final PaletteSnapshot palette;
  final GridGeometry geometry;
  final CellMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final GridScene scene = GridScene(
      geometry: geometry,
      metrics: metrics,
      columns: grid.width,
      rows: grid.height,
    );
    return ColoredBox(
      color: CupertinoColors.secondarySystemFill.resolveFrom(context),
      child: FittedBox(
        child: SizedBox(
          width: scene.size.width,
          height: scene.size.height,
          child: CustomPaint(
            painter: _ThumbnailPainter(grid: grid, palette: palette, scene: scene),
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  const _ThumbnailPainter({required this.grid, required this.palette, required this.scene});

  final Grid grid;
  final PaletteSnapshot palette;
  final GridScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    // Сглаживание кромок выключено: на мелкой миниатюре швов между ячейками быть не должно.
    paint.isAntiAlias = false;
    final double grow = math.min(0.5, scene.cellSize.shortestSide * 0.02);
    for (int row = 0; row < grid.height; row++) {
      for (int column = 0; column < grid.width; column++) {
        final int value = grid.at(column, row);
        if (value == 0) continue;
        final PatternColor? color = palette.colorAt(value);
        if (color == null) continue;
        paint.color = Color.fromARGB(255, color.rgb.r, color.rgb.g, color.rgb.b);
        canvas.drawRect(scene.cellRect(CellPosition(column, row)).inflate(grow), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ThumbnailPainter oldDelegate) =>
      oldDelegate.grid != grid || oldDelegate.palette != palette || oldDelegate.scene != scene;
}
