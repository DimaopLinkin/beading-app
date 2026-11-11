import 'dart:math' as math;
import 'dart:ui';

/// Плоское рисование клеток вышивки (стили схемы) и то, что общее для всех видов вышивки на экране.
abstract final class StitchCells {
  /// Доля цвета подложки, на которую притушен не подсвеченный цвет.
  static const double dimAmount = 0.8;

  /// Цвет [base], притушенный к [surface] (подсветка одного цвета).
  static Color dim(Color base, Color surface) => Color.lerp(base, surface, dimAmount)!;

  /// Толщина стежка относительно меньшей стороны клетки: 2 нитки — `0,32`, как в реалистичном виде.
  static double strandWidth(int strands) => math.min(0.5, 0.2 + 0.06 * strands);

  /// Плоский крестик: нижний стежок `/`, верхний `\` (всегда в эту сторону), верхний чуть светлее.
  static void paintFlatCross(Canvas canvas, Paint paint, Rect cell, Color base, int strands) {
    final double s = math.min(cell.width, cell.height);
    final Rect r = cell.deflate(s * 0.12);
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * strandWidth(strands) * 0.8
      ..color = Color.lerp(base, const Color(0xFF000000), 0.08)!;
    canvas.drawLine(r.bottomLeft, r.topRight, paint);
    paint.color = Color.lerp(base, const Color(0xFFFFFFFF), 0.08)!;
    canvas.drawLine(r.topLeft, r.bottomRight, paint);
    paint
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }
}
