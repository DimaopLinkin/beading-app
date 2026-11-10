import 'dart:math' as math;

import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/presentation/grid_pattern/grid_colors.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:flutter/rendering.dart';

/// Слой подсветки поверх ячеек: вуаль на пройденных рядах, двойное кольцо текущего ряда, метки бусин и текущая бусина.
/// Рисуется заново при каждом изменении настроек: он дешёвый и в кеш `Picture` не входит.
class GridOverlayPainter extends CustomPainter {
  const GridOverlayPainter({required this.scene, required this.options, required this.veil});

  final GridScene scene;
  final GridViewOptions options;

  /// Цвет вуали, уже подобранный под тему.
  final Color veil;

  /// Двойное кольцо вокруг [rect]: белое снаружи, почти чёрное внутри.
  static void paintDoubleRing(Canvas canvas, Rect rect, {required double width, required double radius}) {
    final Paint outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 2
      ..color = GridColors.ringOuter;
    final Paint inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = GridColors.ringInner;
    canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(width * 1.5), Radius.circular(radius + width)), outer);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(width * 0.5), Radius.circular(radius)), inner);
  }

  /// То же двойное кольцо вдоль произвольного контура (ступенчатый ряд пейота и кирпича).
  static void paintDoubleRingPath(Canvas canvas, Path path, {required double width}) {
    final Paint outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width * 3
      ..color = GridColors.ringOuter;
    final Paint inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = GridColors.ringInner;
    canvas.drawPath(path, outer);
    canvas.drawPath(path, inner);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double shortSide = math.min(scene.cellSize.width, scene.cellSize.height);
    final int? current = options.currentRow;
    final Paint veilPaint = Paint()..color = veil;

    // Пройденные ряды: подряд идущие сливаем в один прямоугольник.
    final List<int> done = options.doneRows.where((r) => r >= 0 && r < scene.rows && r != current).toList()..sort();
    if (scene.geometry is RectangularGeometry) {
      int i = 0;
      while (i < done.length) {
        int j = i;
        while (j + 1 < done.length && done[j + 1] == done[j] + 1) {
          j++;
        }
        canvas.drawRect(scene.rowBounds(done[i]).expandToInclude(scene.rowBounds(done[j])), veilPaint);
        i = j + 1;
      }
    } else {
      // Ступенчатые ряды: вуаль ровно по ячейкам, не заходя на соседний ряд.
      final Path veilPath = Path();
      for (final int row in done) {
        veilPath.addPath(scene.rowPath(row), Offset.zero);
      }
      canvas.drawPath(veilPath, veilPaint);
    }

    if (current != null && current >= 0 && current < scene.rows) {
      final double ringWidth = math.max(1.5, shortSide * 0.09);
      if (scene.geometry is RectangularGeometry) {
        paintDoubleRing(canvas, scene.rowBounds(current), width: ringWidth, radius: shortSide * 0.3);
      } else {
        paintDoubleRingPath(canvas, scene.rowPath(current, outline: true), width: ringWidth);
      }
      if (options.markCurrentRowBeads) {
        final Paint dot = Paint()..color = GridColors.ringInner;
        final Paint halo = Paint()..color = GridColors.ringOuter;
        for (int column = 0; column < scene.columns; column++) {
          final Offset c = scene.cellRect(CellPosition(column, current)).center;
          canvas.drawCircle(c, shortSide * 0.16, halo);
          canvas.drawCircle(c, shortSide * 0.1, dot);
        }
      }
    }

    final ({int column, int row})? cell = options.currentCell;
    if (cell != null && cell.row >= 0 && cell.row < scene.rows && cell.column >= 0 && cell.column < scene.columns) {
      paintDoubleRing(
        canvas,
        scene.cellRect(CellPosition(cell.column, cell.row)).deflate(shortSide * 0.04),
        width: math.max(2, shortSide * 0.11),
        radius: shortSide * 0.3,
      );
    }
  }

  @override
  bool shouldRepaint(GridOverlayPainter oldDelegate) =>
      oldDelegate.options != options || oldDelegate.veil != veil || oldDelegate.scene != scene;
}
