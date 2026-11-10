import 'dart:math' as math;

import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/rendering.dart';

/// Слой подсветки поверх ячеек: вуаль на пройденных рядах, двойное кольцо текущего ряда, метки бусин и текущая бусина.
/// Рисуется заново при каждом изменении настроек: он дешёвый и в кеш `Picture` не входит.
class GridOverlayPainter extends CustomPainter {
  const GridOverlayPainter({required this.scene, required this.options, required this.veil, required this.ring});

  final GridScene scene;
  final GridViewOptions options;

  /// Цвет вуали, уже подобранный под тему.
  final Color veil;

  /// Токен двойного кольца текущего ряда.
  final RowRingTokens ring;

  /// Двойное кольцо вокруг [rect]: внутренняя линия, широкое белое кольцо и тонкая внешняя кромка (токен `rowRing`).
  /// [width] — толщина внутренней линии; остальное по пропорциям токена.
  static void paintDoubleRing(
    Canvas canvas,
    Rect rect, {
    required RowRingTokens ring,
    required double width,
    required double radius,
  }) {
    double offset = 0;
    void band(Color color, double w) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(offset + w / 2), Radius.circular(radius + offset + w / 2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = color,
      );
      offset += w;
    }

    band(ring.inner, width);
    band(ring.outer, width * ring.outerWidth / ring.innerWidth);
    band(ring.inner, width * ring.edgeWidth / ring.innerWidth);
  }

  /// То же двойное кольцо вдоль произвольного контура (ступенчатый ряд пейота и кирпича).
  static void paintDoubleRingPath(Canvas canvas, Path path, {required RowRingTokens ring, required double width}) {
    final double outer = width * ring.outerWidth / ring.innerWidth;
    final double edge = width * ring.edgeWidth / ring.innerWidth;
    void stroke(Color color, double w) => canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = w
        ..color = color,
    );
    // Кольцо целиком снаружи ряда, как у прямоугольника: внутренность контура вырезаем из области рисования.
    canvas.save();
    canvas.clipPath(
      Path.combine(PathOperation.difference, Path()..addRect(canvas.getLocalClipBounds().inflate(1)), path),
    );
    // Слои от самого широкого к самому узкому; обводка центрирована по контуру, снаружи остаётся её половина.
    stroke(ring.inner, (width + outer + edge) * 2);
    stroke(ring.outer, (width + outer) * 2);
    stroke(ring.inner, width * 2);
    canvas.restore();
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
        paintDoubleRing(canvas, scene.rowBounds(current), ring: ring, width: ringWidth, radius: shortSide * 0.3);
      } else {
        paintDoubleRingPath(canvas, scene.rowPath(current, outline: true), ring: ring, width: ringWidth);
      }
      if (options.markCurrentRowBeads) {
        final Paint dot = Paint()..color = ring.inner;
        final Paint halo = Paint()..color = ring.outer;
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
        ring: ring,
        width: math.max(2, shortSide * 0.11),
        radius: shortSide * 0.3,
      );
    }
  }

  @override
  bool shouldRepaint(GridOverlayPainter oldDelegate) =>
      oldDelegate.options != options ||
      oldDelegate.veil != veil ||
      oldDelegate.ring != ring ||
      oldDelegate.scene != scene;
}
