import 'package:beading/presentation/theme/app_theme.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/row_ring.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('кольцо рисуется снаружи ребёнка и не меняет его размер', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        builder: AppTheme.builder,
        home: Center(child: RowRing(child: SizedBox(width: 100, height: 20))),
      ),
    );

    expect(tester.getSize(find.byType(RowRing)), const Size(100, 20));
    expect(find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter is RowRingPainter), findsOneWidget);
  });

  test('три контура: внутренний, белый, кайма; перерисовка только при смене токенов', () {
    const RowRingTokens ring = RowRingTokens(inner: Color(0xFF151316), outer: Color(0xFFFFFFFF));
    expect(const RowRingPainter(ring).shouldRepaint(const RowRingPainter(ring)), isFalse);
    expect(
      const RowRingPainter(ring).shouldRepaint(
        const RowRingPainter(RowRingTokens(inner: Color(0xFF000000), outer: Color(0xFFFFFFFF))),
      ),
      isTrue,
    );
    expect(ring.innerWidth + ring.outerWidth + ring.edgeWidth, 5.5);
  });
}
