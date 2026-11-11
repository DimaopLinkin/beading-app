import 'dart:math' as math;
import 'dart:ui';

import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/presentation/grid_pattern/bead_finish.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:beading/presentation/grid_pattern/stitch_cells.dart';

/// Из чего сделана вещь на экране «как будет выглядеть».
enum RealisticMaterial {
  /// Рокайль: округлая бусина.
  roundBead,

  /// Цилиндрическая бусина (Delica, Toho Treasure): ровный цилиндр с острыми краями.
  cylinderBead,

  /// Вышивка крестиком по канве Аида.
  crossStitch
  ;

  /// Материал по размерам ячейки: бусина берёт форму из [BeadSize], всё остальное — ткань с крестиками.
  static RealisticMaterial forMetrics(CellMetrics metrics) {
    if (metrics is BeadSize) {
      return metrics.shape == BeadShape.delica ? RealisticMaterial.cylinderBead : RealisticMaterial.roundBead;
    }
    return RealisticMaterial.crossStitch;
  }

  bool get isBead => this != RealisticMaterial.crossStitch;
}

/// Цвета фона и нити реалистичного вида.
final class RealisticColors {
  const RealisticColors({required this.surface, required this.thread});

  /// Подложка: ткань под бисером или канва Аида.
  final Color surface;

  /// Нить между бусинами.
  final Color thread;

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, поля final
  bool operator ==(Object other) => other is RealisticColors && other.surface == surface && other.thread == thread;

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, см. выше
  int get hashCode => Object.hash(surface, thread);
}

/// Реалистичное рисование ячеек: бусины с бликом и тенью, крестики на канве Аида.
///
/// Чистые функции над `Canvas`: тот же код рисует вид в приложении (через кеш слоя блоков) и листы галереи генератора.
/// Всё, что рисует ячейка, лежит внутри её прямоугольника, поэтому блоки не затирают друг друга на стыках, а
/// сдвинутые ряды пейота и кирпича не мешают соседям.
abstract final class RealisticCells {
  /// Рисует подложку на [area] (часть сцены).
  static void paintSurface(Canvas canvas, Rect area, RealisticColors colors) {
    canvas.drawRect(area, Paint()..color = colors.surface);
  }

  /// Рисует ячейки `[c0, c1) × [r0, r1)`.
  static void paintBlock(
    Canvas canvas, {
    required GridScene scene,
    required Grid grid,
    required PaletteSnapshot palette,
    required RealisticColors colors,
    required RealisticMaterial material,
    required int c0,
    required int c1,
    required int r0,
    required int r1,
    int Function(int color)? strandsFor,
    int? highlight,
  }) {
    final Paint paint = Paint();
    // Не подсвеченный цвет притушен к подложке (подсветка одного цвета).
    Color shown(int value, Color base) =>
        highlight != null && highlight != value ? StitchCells.dim(base, colors.surface) : base;
    if (material == RealisticMaterial.crossStitch) {
      _fabric(canvas, scene, paint, c0, c1, r0, r1);
      for (int row = r0; row < r1; row++) {
        for (int column = c0; column < c1; column++) {
          final int value = grid.at(column, row);
          if (value == 0) continue;
          _stitch(
            canvas,
            paint,
            scene.cellRect(CellPosition(column, row)),
            shown(value, _rgb(palette.colorAt(value))),
            strandsFor?.call(value) ?? 2,
          );
        }
      }
      return;
    }
    // Нить под бусинами видна только в зазорах: сначала нить по всем ячейкам блока.
    for (int row = r0; row < r1; row++) {
      for (int column = c0; column < c1; column++) {
        if (grid.at(column, row) == 0) continue;
        _thread(canvas, paint, scene.cellRect(CellPosition(column, row)), colors.thread);
      }
    }
    for (int row = r0; row < r1; row++) {
      for (int column = c0; column < c1; column++) {
        final int value = grid.at(column, row);
        if (value == 0) continue;
        final PatternColor? color = palette.colorAt(value);
        _bead(
          canvas,
          paint,
          scene.cellRect(CellPosition(column, row)),
          shown(value, _rgb(color)),
          BeadFinish.parse(color?.finish),
          cylinder: material == RealisticMaterial.cylinderBead,
        );
      }
    }
  }

  static Color _rgb(PatternColor? color) =>
      color == null ? const Color(0xFFC7C7CC) : Color.fromARGB(255, color.rgb.r, color.rgb.g, color.rgb.b);

  static const Color _black = Color(0xFF000000);
  static const Color _white = Color(0xFFFFFFFF);

  static Color _a(Color base, double opacity) => base.withValues(alpha: opacity);

  /// Нить вдоль отверстия бусины: вдоль короткой стороны ячейки.
  static void _thread(Canvas canvas, Paint paint, Rect cell, Color thread) {
    final double s = math.min(cell.width, cell.height);
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = math.max(0.6, s * 0.1)
      ..color = thread;
    if (cell.width <= cell.height) {
      canvas.drawLine(Offset(cell.left, cell.center.dy), Offset(cell.right, cell.center.dy), paint);
    } else {
      canvas.drawLine(Offset(cell.center.dx, cell.top), Offset(cell.center.dx, cell.bottom), paint);
    }
    paint.style = PaintingStyle.fill;
  }

  static void _bead(
    Canvas canvas,
    Paint paint,
    Rect cell,
    Color base,
    BeadFinish finish, {
    required bool cylinder,
  }) {
    final double s = math.min(cell.width, cell.height);
    paint
      ..shader = null
      ..style = PaintingStyle.fill;

    // Тень: бусина, сдвинутая вниз и вправо, но не дальше своей ячейки.
    final Rect body = cell.deflate(s * 0.06);
    final Rect shadow = body.shift(Offset(s * 0.06, s * 0.08)).intersect(cell);
    paint.color = _a(_black, 0.3);
    canvas.drawRRect(RRect.fromRectAndRadius(shadow, Radius.circular(s * (cylinder ? 0.16 : 0.4))), paint);

    // Отверстие идёт вдоль короткой стороны ячейки; рисуем в системе, где оно горизонтально.
    final bool horizontal = cell.width <= cell.height;
    if (!horizontal) {
      canvas
        ..save()
        ..translate(cell.center.dx, cell.center.dy)
        ..rotate(-math.pi / 2)
        ..translate(-cell.center.dx, -cell.center.dy);
    }
    final Rect b = horizontal ? body : Rect.fromCenter(center: cell.center, width: body.height, height: body.width);
    if (cylinder) {
      _cylinder(canvas, paint, b, base, finish);
    } else {
      _round(canvas, paint, b, base, finish);
    }
    if (!horizontal) canvas.restore();
  }

  /// Цилиндр: светлая полоса сверху, тёмная снизу, блик, кромка.
  static void _cylinder(Canvas canvas, Paint paint, Rect b, Color base, BeadFinish finish) {
    final double w = b.width;
    final double h = b.height;
    final Radius radius = Radius.circular(math.min(w, h) * 0.16);
    final RRect outer = RRect.fromRectAndRadius(b, radius);
    final (double light, double dark, double spec) = switch (finish) {
      BeadFinish.glossy => (0.34, 0.22, 0.75),
      BeadFinish.matte => (0.1, 0.14, 0),
      BeadFinish.metallic => (0.55, 0.34, 0.9),
      BeadFinish.transparent => (0.3, 0.1, 0.8),
    };
    paint.color = finish == BeadFinish.transparent ? Color.lerp(base, _white, 0.38)! : base;
    canvas.drawRRect(outer, paint);
    paint.color = _a(_white, light);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(b.left, b.top, w, h * 0.42), radius), paint);
    paint.color = _a(_black, dark);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(b.left, b.top + h * 0.66, w, h * 0.34), radius), paint);
    if (finish == BeadFinish.transparent) {
      paint.color = _a(_white, 0.35);
      canvas.drawRect(Rect.fromLTWH(b.left, b.top + h * 0.4, w, h * 0.2), paint);
    }
    if (spec > 0) {
      paint.color = _a(_white, spec);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(b.left + w * 0.16, b.top + h * 0.15, w * 0.46, h * 0.14),
          Radius.circular(h * 0.07),
        ),
        paint,
      );
    }
    _outline(canvas, paint, outer, finish == BeadFinish.transparent ? base : _black, finish);
  }

  /// Рокайль: округлая, светлый «купол» ближе к источнику света, блик, тёмная кромка.
  static void _round(Canvas canvas, Paint paint, Rect b, Color base, BeadFinish finish) {
    final double w = b.width;
    final double h = b.height;
    final double s = math.min(w, h);
    final RRect outer = RRect.fromRectAndRadius(b, Radius.circular(s * 0.45));
    final (double dome, double shade, double spec) = switch (finish) {
      BeadFinish.glossy => (0.26, 0.2, 0.8),
      BeadFinish.matte => (0.1, 0.16, 0),
      BeadFinish.metallic => (0.5, 0.34, 0.9),
      BeadFinish.transparent => (0.3, 0.1, 0.8),
    };
    paint.color = finish == BeadFinish.transparent ? Color.lerp(base, _white, 0.38)! : base;
    canvas.drawRRect(outer, paint);
    paint.color = _a(_black, shade);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(b.left + w * 0.3, b.top + h * 0.38, w * 0.7, h * 0.62),
        Radius.circular(s * 0.45),
      ),
      paint,
    );
    paint.color = _a(_white, dome);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(b.left + w * 0.1, b.top + h * 0.08, w * 0.66, h * 0.6),
        Radius.circular(s * 0.3),
      ),
      paint,
    );
    if (spec > 0) {
      paint.color = _a(_white, spec);
      canvas.drawOval(Rect.fromLTWH(b.left + w * 0.2, b.top + h * 0.14, w * 0.28, h * 0.2), paint);
    }
    _outline(canvas, paint, outer, finish == BeadFinish.transparent ? base : _black, finish);
  }

  static void _outline(Canvas canvas, Paint paint, RRect shape, Color color, BeadFinish finish) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, math.min(shape.width, shape.height) * 0.06)
      ..color = _a(color, finish == BeadFinish.transparent ? 0.9 : 0.34);
    canvas.drawRRect(shape.deflate(paint.strokeWidth / 2), paint);
    paint.style = PaintingStyle.fill;
  }

  /// Канва Аида: блоки с отверстиями на углах и тонкими нитями.
  static void _fabric(Canvas canvas, GridScene scene, Paint paint, int c0, int c1, int r0, int r1) {
    for (int row = r0; row < r1; row++) {
      for (int column = c0; column < c1; column++) {
        final Rect cell = scene.cellRect(CellPosition(column, row));
        final double s = math.min(cell.width, cell.height);
        paint
          ..shader = null
          ..style = PaintingStyle.fill
          ..color = _a(_white, 0.12);
        canvas.drawRRect(RRect.fromRectAndRadius(cell.deflate(s * 0.05), Radius.circular(s * 0.14)), paint);
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0
          ..color = _a(_black, 0.07);
        for (int i = 1; i <= 3; i++) {
          final double t = i / 4;
          canvas
            ..drawLine(
              Offset(cell.left + s * 0.1, cell.top + cell.height * t),
              Offset(cell.right - s * 0.1, cell.top + cell.height * t),
              paint,
            )
            ..drawLine(
              Offset(cell.left + cell.width * t, cell.top + s * 0.1),
              Offset(cell.left + cell.width * t, cell.bottom - s * 0.1),
              paint,
            );
        }
        paint
          ..style = PaintingStyle.fill
          ..color = _a(_black, 0.3);
        canvas.drawOval(Rect.fromCenter(center: cell.topLeft, width: s * 0.17, height: s * 0.17), paint);
      }
    }
  }

  /// Крестик: нижний стежок «/», поверх него верхний «\», светлее.
  static void _stitch(Canvas canvas, Paint paint, Rect cell, Color base, int strands) {
    final double s = math.min(cell.width, cell.height);
    final Rect r = cell.deflate(s * 0.12);
    final double width = s * StitchCells.strandWidth(strands);
    _strand(canvas, paint, r.bottomLeft, r.topRight, s, width, Color.lerp(base, _black, 0.1)!, 0.22);
    _strand(canvas, paint, r.topLeft, r.bottomRight, s, width, Color.lerp(base, _white, 0.1)!, 0.3);
  }

  /// Один стежок: тень, тело, щель между двумя нитками и по блику на каждой.
  static void _strand(
    Canvas canvas,
    Paint paint,
    Offset from,
    Offset to,
    double s,
    double width,
    Color color,
    double shadow,
  ) {
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;
    final Offset lift = Offset(s * 0.035, s * 0.05);
    paint.color = _a(_black, shadow);
    canvas.drawLine(from + lift, to + lift, paint);
    paint.color = color;
    canvas.drawLine(from, to, paint);
    paint
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = math.max(0.5, width * 0.1)
      ..color = _a(_black, 0.2);
    final Offset along = to - from;
    final Offset unit = along / along.distance;
    final Offset inset = unit * (s * 0.05);
    canvas.drawLine(from + inset, to - inset, paint);
    final Offset normal = Offset(-unit.dy, unit.dx);
    paint
      ..strokeWidth = math.max(0.5, width * 0.12)
      ..color = _a(_white, 0.28);
    for (final double side in <double>[-1, 1]) {
      final Offset shift = normal * (side * width * 0.24);
      canvas.drawLine(from + inset * 1.6 + shift, to - inset * 1.6 + shift, paint);
    }
    paint
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }
}
