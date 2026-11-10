import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';

/// Двойное кольцо вокруг текущего ряда (01b, п. 3): внутреннее почти чёрное, внешнее белое, тонкая чёрная кайма.
/// Рисуется снаружи [child], поэтому не закрывает бусины ряда и отличимо от любых цветов бусин и фонов.
class RowRing extends StatelessWidget {
  const RowRing({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(foregroundPainter: RowRingPainter(context.tokens.rowRing), child: child);
  }
}

/// Рисует три концентрических контура за границами своей области.
class RowRingPainter extends CustomPainter {
  const RowRingPainter(this.ring);

  final RowRingTokens ring;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect box = Offset.zero & size;
    double offset = 0;
    void band(Color color, double width) {
      final Rect rect = box.inflate(offset + width / 2);
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color,
      );
      offset += width;
    }

    band(ring.inner, ring.innerWidth);
    band(ring.outer, ring.outerWidth);
    band(ring.inner, ring.edgeWidth);
  }

  @override
  bool shouldRepaint(RowRingPainter oldDelegate) => oldDelegate.ring != ring;
}
