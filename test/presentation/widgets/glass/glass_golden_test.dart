import 'package:beading/presentation/widgets/glass/glass_bar.dart';
import 'package:beading/presentation/widgets/glass/glass_button.dart';
import 'package:beading/presentation/widgets/glass/glass_panel.dart';
import 'package:beading/presentation/widgets/glass/glass_policy.dart';
import 'package:beading/presentation/widgets/glass/glass_sheet.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glass_harness.dart';

/// Схема 100×400 ярких бусин (детерминированно): стекло должно оставаться читаемым над самыми тяжёлыми цветами.
class _BeadGridPainter extends CustomPainter {
  const _BeadGridPainter();

  static const List<Color> _palette = <Color>[
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFFFF00FF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const int columns = 100;
    const int rows = 400;
    final double cell = size.width / columns;
    final Paint paint = Paint();
    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < columns; column++) {
        paint.color = _palette[(row * 3 + column * 5 + (row ~/ 7)) % _palette.length];
        canvas.drawRect(Rect.fromLTWH(column * cell, row * cell, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Scene extends StatelessWidget {
  const _Scene();

  @override
  Widget build(BuildContext context) {
    final Widget label = Text('Ряд 12', style: TextStyle(color: CupertinoColors.label.resolveFrom(context)));
    return SizedBox(
      width: 320,
      height: 520,
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: RepaintBoundary(child: CustomPaint(painter: _BeadGridPainter())),
          ),
          Positioned(top: 16, left: 16, right: 16, child: GlassPanel(child: label)),
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            child: GlassPanel(density: GlassDensity.dense, child: label),
          ),
          Positioned(
            top: 190,
            left: 16,
            child: GlassButton(semanticLabel: 'Вперёд', onPressed: () {}, child: const Icon(CupertinoIcons.add)),
          ),
          Positioned(
            top: 190,
            left: 90,
            child: GlassButton(
              semanticLabel: 'Назад',
              density: GlassDensity.dense,
              onPressed: () {},
              child: const Icon(CupertinoIcons.minus),
            ),
          ),
          Positioned(top: 270, left: 16, right: 16, child: GlassBar(child: label)),
          Positioned(left: 0, right: 0, bottom: 0, child: GlassSheet(child: label)),
        ],
      ),
    );
  }
}

void main() {
  for (final Brightness brightness in Brightness.values) {
    for (final bool opaque in <bool>[false, true]) {
      final String name = '${brightness.name}${opaque ? '_opaque' : ''}';
      testWidgets('стекло над схемой 100×400, $name', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 520));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpGlass(
          tester,
          GlassPolicy(reduceTransparency: opaque, child: const _Scene()),
          brightness: brightness,
        );

        await expectLater(find.byType(_Scene), matchesGoldenFile('goldens/glass_scene_$name.png'));
      });
    }
  }
}
