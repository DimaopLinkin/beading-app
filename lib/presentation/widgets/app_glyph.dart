import 'package:flutter/cupertino.dart';

/// Иконки, которых нет ни в CupertinoIcons, ни в SF Symbols (01b, п. 6): ластик, выделение, зеркало, режим «по бусине».
/// Линии толщиной 2 pt на сетке 24 × 24, как в макете; цвет и размер берутся из [IconTheme].
enum AppGlyphKind {
  eraser,
  selection,
  mirror,
  beadMode,

  /// Клетка с одной диагональю.
  halfStitch,

  /// Клетка со стежком от угла до центра.
  quarterStitch,

  /// Клетка с диагональю и четвертью.
  threeQuarterStitch,

  /// Маленький крестик в углу клетки.
  petit,

  /// Ломаная по узлам.
  backstitch,

  /// Французский узелок: кольцо с точкой.
  knot,
}

class AppGlyph extends StatelessWidget {
  const AppGlyph(this.kind, {this.size, this.color, super.key});

  final AppGlyphKind kind;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final IconThemeData theme = IconTheme.of(context);
    final double side = size ?? theme.size ?? 24;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(side),
        painter: AppGlyphPainter(kind, color ?? theme.color ?? const Color(0xFF000000)),
      ),
    );
  }
}

class AppGlyphPainter extends CustomPainter {
  const AppGlyphPainter(this.kind, this.color);

  final AppGlyphKind kind;
  final Color color;

  /// Контуры в координатах 24 × 24: списки точек, замкнутые помечены.
  static List<(List<Offset>, bool)> outlines(AppGlyphKind kind) => switch (kind) {
    AppGlyphKind.eraser => <(List<Offset>, bool)>[
      (const <Offset>[Offset(8, 20), Offset(20, 20)], false),
      (const <Offset>[Offset(5, 15), Offset(14, 6), Offset(19, 11), Offset(13, 17), Offset(8, 17)], true),
    ],
    AppGlyphKind.selection => <(List<Offset>, bool)>[
      for (final (double x, double y, double dx, double dy) c in <(double, double, double, double)>[
        (5, 5, 4, 4),
        (19, 5, -4, 4),
        (5, 19, 4, -4),
        (19, 19, -4, -4),
      ])
        (<Offset>[Offset(c.$1 + c.$3, c.$2), Offset(c.$1, c.$2), Offset(c.$1, c.$2 + c.$4)], false),
    ],
    AppGlyphKind.mirror => <(List<Offset>, bool)>[
      (const <Offset>[Offset(12, 4), Offset(12, 20)], false),
      (const <Offset>[Offset(8, 7), Offset(3, 12), Offset(8, 17)], true),
      (const <Offset>[Offset(16, 7), Offset(21, 12), Offset(16, 17)], true),
    ],
    AppGlyphKind.beadMode || AppGlyphKind.knot => const <(List<Offset>, bool)>[],
    AppGlyphKind.halfStitch => <(List<Offset>, bool)>[
      (_cellFrame, true),
      (const <Offset>[Offset(5, 19), Offset(19, 5)], false),
    ],
    AppGlyphKind.quarterStitch => <(List<Offset>, bool)>[
      (_cellFrame, true),
      (const <Offset>[Offset(5, 19), Offset(12, 12)], false),
    ],
    AppGlyphKind.threeQuarterStitch => <(List<Offset>, bool)>[
      (_cellFrame, true),
      (const <Offset>[Offset(5, 19), Offset(19, 5)], false),
      (const <Offset>[Offset(5, 5), Offset(12, 12)], false),
    ],
    AppGlyphKind.petit => <(List<Offset>, bool)>[
      (_cellFrame, true),
      (const <Offset>[Offset(6, 12), Offset(12, 6)], false),
      (const <Offset>[Offset(6, 6), Offset(12, 12)], false),
    ],
    AppGlyphKind.backstitch => <(List<Offset>, bool)>[
      (const <Offset>[Offset(4, 18), Offset(10, 18), Offset(10, 8), Offset(20, 8)], false),
    ],
  };

  static const List<Offset> _cellFrame = <Offset>[Offset(4, 4), Offset(20, 4), Offset(20, 20), Offset(4, 20)];

  @override
  void paint(Canvas canvas, Size size) {
    final double k = size.width / 24;
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    if (kind == AppGlyphKind.knot) {
      canvas
        ..drawCircle(Offset(12 * k, 12 * k), 7 * k, stroke)
        ..drawCircle(Offset(12 * k, 12 * k), 2.5 * k, Paint()..color = color);
      return;
    }
    if (kind == AppGlyphKind.beadMode) {
      // Контур бусины с точкой.
      canvas
        ..drawOval(Rect.fromCenter(center: Offset(12 * k, 12 * k), width: 18 * k, height: 18 * k), stroke)
        ..drawCircle(Offset(12 * k, 12 * k), 2.5 * k, Paint()..color = color);
      return;
    }
    for (final (List<Offset> points, bool closed) in outlines(kind)) {
      final Path path = Path()..moveTo(points.first.dx * k, points.first.dy * k);
      for (final Offset p in points.skip(1)) {
        path.lineTo(p.dx * k, p.dy * k);
      }
      if (closed) {
        path.close();
      }
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(AppGlyphPainter oldDelegate) => oldDelegate.kind != kind || oldDelegate.color != color;
}
