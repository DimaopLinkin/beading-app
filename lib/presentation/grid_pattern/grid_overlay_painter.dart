import 'dart:math' as math;

import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid/reading_order.dart';
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
    if (options.showCenter) _paintCenter(canvas, shortSide);
    final ReadingOrder? order = options.order;
    if (order != null) {
      _paintReading(canvas, order, shortSide);
      return;
    }
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

  /// Центр схемы: треугольники на всех четырёх краях, острием внутрь. Для чётной ширины или высоты центр лежит
  /// на линии между клетками.
  void _paintCenter(Canvas canvas, double shortSide) {
    final Rect all = Offset.zero & scene.size;
    final double size = math.max(4, shortSide * 0.45);
    final Path path = Path();
    final double cx = all.center.dx;
    final double cy = all.center.dy;
    path
      ..moveTo(cx - size / 2, all.top)
      ..lineTo(cx + size / 2, all.top)
      ..lineTo(cx, all.top + size)
      ..close()
      ..moveTo(cx - size / 2, all.bottom)
      ..lineTo(cx + size / 2, all.bottom)
      ..lineTo(cx, all.bottom - size)
      ..close()
      ..moveTo(all.left, cy - size / 2)
      ..lineTo(all.left, cy + size / 2)
      ..lineTo(all.left + size, cy)
      ..close()
      ..moveTo(all.right, cy - size / 2)
      ..lineTo(all.right, cy + size / 2)
      ..lineTo(all.right - size, cy)
      ..close();
    canvas
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, size * 0.3)
          ..strokeJoin = StrokeJoin.round
          ..color = ring.outer,
      )
      ..drawPath(path, Paint()..color = ring.inner);
  }

  /// Подсветка по порядку плетения: ряд — это набор ячеек [ReadingRow], а не ряд сетки.
  void _paintReading(Canvas canvas, ReadingOrder order, double shortSide) {
    final int? current = options.currentRow;
    final Paint veilPaint = Paint()..color = veil;
    final bool plain = scene.geometry is RectangularGeometry;

    final List<int> done = options.doneRows.where((r) => r >= 0 && r < order.rowCount && r != current).toList()..sort();
    final Path veilPath = Path();
    for (final int index in done) {
      final Iterable<CellPosition> cells = order.row(index).cells;
      if (plain) {
        veilPath.addRect(scene.cellsBounds(<CellPosition>[cells.first, cells.last]));
      } else {
        veilPath.addPath(scene.cellsPath(cells), Offset.zero);
      }
    }
    canvas.drawPath(veilPath, veilPaint);

    if (current != null && current >= 0 && current < order.rowCount) {
      final List<CellPosition> cells = order.row(current).cells;
      final double ringWidth = math.max(1.5, shortSide * 0.09);
      if (plain) {
        paintDoubleRing(
          canvas,
          scene.cellsBounds(<CellPosition>[cells.first, cells.last]),
          ring: ring,
          width: ringWidth,
          radius: shortSide * 0.3,
        );
      } else {
        paintDoubleRingPath(canvas, scene.cellsPath(cells, outline: true), ring: ring, width: ringWidth);
      }
      if (options.markCurrentRowBeads) {
        final Paint dot = Paint()..color = ring.inner;
        final Paint halo = Paint()..color = ring.outer;
        for (final CellPosition cell in cells) {
          final Offset c = scene.cellRect(cell).center;
          canvas.drawCircle(c, shortSide * 0.16, halo);
          canvas.drawCircle(c, shortSide * 0.1, dot);
        }
      }
    }

    _paintPending(canvas, shortSide);
    _paintCurrentCell(canvas, shortSide);
  }

  /// Ещё не выложенные бусины: вуаль поверх цвета и пунктирный контур, чтобы отличать их от выложенных.
  void _paintPending(Canvas canvas, double shortSide) {
    final Paint fill = Paint()..color = veil;
    final Paint dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, shortSide * 0.07)
      ..color = ring.inner.withValues(alpha: 0.55);
    const int dashes = 10;
    for (final CellPosition cell in options.pendingCells) {
      final Rect rect = scene.cellRect(cell).deflate(shortSide * 0.1);
      final Offset center = rect.center;
      final double radius = math.min(rect.width, rect.height) / 2;
      canvas.drawCircle(center, radius, fill);
      for (int i = 0; i < dashes; i++) {
        final double start = i * 2 * math.pi / dashes;
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, math.pi / dashes, false, dash);
      }
    }
  }

  void _paintCurrentCell(Canvas canvas, double shortSide) {
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
