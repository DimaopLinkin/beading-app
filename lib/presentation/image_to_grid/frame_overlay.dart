import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

/// Положение внутренней сетки (с фото) в полной схеме с полями, в долях полной: T88c.
@immutable
class MarginsLayout {
  const MarginsLayout({required this.left, required this.top, required this.width, required this.height});

  /// Из размеров внутренней и полной сеток и смещения (в клетках).
  factory MarginsLayout.of({
    required int columns,
    required int rows,
    required int innerColumns,
    required int innerRows,
    required int offsetColumn,
    required int offsetRow,
  }) => MarginsLayout(
    left: offsetColumn / columns,
    top: offsetRow / rows,
    width: innerColumns / columns,
    height: innerRows / rows,
  );

  final double left;
  final double top;
  final double width;
  final double height;

  /// Прямоугольник внутренней сетки в области [size].
  Rect inner(Size size) =>
      Rect.fromLTWH(left * size.width, top * size.height, width * size.width, height * size.height);
}

/// Что рисовать поверх предпросмотра схемы.
enum FrameOverlayKind {
  /// Поля: нейтральная штриховка вокруг внутренней сетки и пунктирная граница схемы (режим «Оставить поля»).
  margins,

  /// Кадр: сплошная рамка по краю схемы (режим «Обрезать», когда фото кадрируется под высоту).
  frame,
}

/// Штриховка полей и рамка кадра поверх предпросмотра схемы (T88c). Цвета нейтральные: цвета бусин и крестиков не
/// тонируются.
class FrameOverlayPainter extends CustomPainter {
  const FrameOverlayPainter({required this.kind, required this.color, this.layout});

  final FrameOverlayKind kind;
  final Color color;

  /// Внутренняя сетка; нужна для [FrameOverlayKind.margins].
  final MarginsLayout? layout;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    switch (kind) {
      case FrameOverlayKind.frame:
        canvas.drawRect(
          all.deflate(1),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color,
        );
      case FrameOverlayKind.margins:
        final Rect inner = (layout ?? const MarginsLayout(left: 0, top: 0, width: 1, height: 1)).inner(size);
        final Path margins = Path.combine(PathOperation.difference, Path()..addRect(all), Path()..addRect(inner));
        canvas.save();
        canvas.clipPath(margins);
        final Paint line = Paint()
          ..color = color.withValues(alpha: 0.55)
          ..strokeWidth = 1.2;
        const double step = 7;
        for (double x = -size.height; x < size.width; x += step) {
          canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
        }
        canvas.restore();
        _dashed(
          canvas,
          Path()..addRect(inner),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = color,
        );
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    const double dash = 5;
    const double gap = 4;
    for (final ui.PathMetric metric in path.computeMetrics()) {
      double at = 0;
      while (at < metric.length) {
        canvas.drawPath(metric.extractPath(at, math.min(at + dash, metric.length)), paint);
        at += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(FrameOverlayPainter old) => old.kind != kind || old.color != color || old.layout != layout;
}
