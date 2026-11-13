import 'package:beading/domain/image_pattern/book_work/page_markup.dart';
import 'package:flutter/cupertino.dart';

/// Мазок, который ведёт палец прямо сейчас: точки пары `x, y` в долях ширины страницы.
class LiveStroke {
  const LiveStroke({required this.rgb, required this.width, required this.points});

  final int rgb;
  final double width;
  final List<double> points;
}

/// Прозрачность маркера: символы и цвета схемы под мазком остаются читаемыми.
const double markerOpacity = 0.55;

/// Рисует пометки маркером поверх страницы. Мазки смешиваются «умножением», как настоящий маркер.
class MarkupPainter extends CustomPainter {
  MarkupPainter({required this.markup, required this.visible, this.live}) : super(repaint: live);

  final PageMarkup markup;
  final bool visible;
  final ValueNotifier<LiveStroke?>? live;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) {
      return;
    }
    for (final MarkerStroke stroke in markup.strokes) {
      _paintStroke(canvas, size.width, stroke.rgb, stroke.width, stroke.points);
    }
    final LiveStroke? now = live?.value;
    if (now != null) {
      _paintStroke(canvas, size.width, now.rgb, now.width, now.points);
    }
  }

  void _paintStroke(Canvas canvas, double pageWidth, int rgb, double width, List<double> points) {
    if (points.length < 2) {
      return;
    }
    final Paint paint = Paint()
      ..color = Color(0xFF000000 | rgb).withValues(alpha: markerOpacity)
      ..blendMode = BlendMode.multiply
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width * pageWidth;
    if (points.length == 2) {
      canvas.drawCircle(
        Offset(points[0] * pageWidth, points[1] * pageWidth),
        width * pageWidth / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }
    final Path path = Path()..moveTo(points[0] * pageWidth, points[1] * pageWidth);
    for (int i = 2; i + 1 < points.length; i += 2) {
      path.lineTo(points[i] * pageWidth, points[i + 1] * pageWidth);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(MarkupPainter oldDelegate) =>
      oldDelegate.markup != markup || oldDelegate.visible != visible || oldDelegate.live != live;
}
