import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/widgets/app_glyph.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('глиф занимает квадрат заданного размера и скрыт из семантики', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: AppGlyph(AppGlyphKind.eraser, size: 32)),
      ),
    );

    expect(tester.getSize(find.byType(CustomPaint).last), const Size(32, 32));
  });

  test('у каждого глифа есть контуры (кроме режима «по бусине», он рисуется кругом)', () {
    for (final AppGlyphKind kind in AppGlyphKind.values) {
      expect(AppGlyphPainter.outlines(kind).isEmpty, kind == AppGlyphKind.beadMode);
    }
  });

  test('перерисовка при смене цвета или вида', () {
    const AppGlyphPainter p = AppGlyphPainter(AppGlyphKind.mirror, Color(0xFF000000));
    expect(p.shouldRepaint(const AppGlyphPainter(AppGlyphKind.mirror, Color(0xFF000000))), isFalse);
    expect(p.shouldRepaint(const AppGlyphPainter(AppGlyphKind.mirror, Color(0xFFFFFFFF))), isTrue);
    expect(p.shouldRepaint(const AppGlyphPainter(AppGlyphKind.eraser, Color(0xFF000000))), isTrue);
  });

  test('соответствие SF Symbols задано для каждого инструмента', () {
    expect(AppIcons.sfSymbols['brush'], 'paintbrush.pointed');
    expect(AppIcons.sfSymbols.keys, containsAll(<String>['eraser', 'fill', 'pipette', 'undo', 'redo']));
  });
}
