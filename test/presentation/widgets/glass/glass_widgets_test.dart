import 'dart:ui' show Tristate;

import 'package:beading/presentation/widgets/glass/glass_bar.dart';
import 'package:beading/presentation/widgets/glass/glass_button.dart';
import 'package:beading/presentation/widgets/glass/glass_panel.dart';
import 'package:beading/presentation/widgets/glass/glass_sheet.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glass_harness.dart';

void main() {
  group('GlassPanel', () {
    testWidgets('показывает ребёнка на стеклянной поверхности с отступами токенов', (tester) async {
      await pumpGlass(tester, const GlassPanel(child: Text('Панель')));

      expect(find.text('Панель'), findsOneWidget);
      expect(find.byType(GlassSurface), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('плотный вариант передаётся поверхности', (tester) async {
      await pumpGlass(tester, const GlassPanel(density: GlassDensity.dense, child: Text('x')));

      expect(tester.widget<GlassSurface>(find.byType(GlassSurface)).density, GlassDensity.dense);
    });
  });

  group('GlassBar', () {
    testWidgets('использует материал bar', (tester) async {
      await pumpGlass(tester, const GlassBar(child: Text('Бар')));

      expect(tester.widget<GlassSurface>(find.byType(GlassSurface)).material, GlassMaterial.bar);
      expect(find.text('Бар'), findsOneWidget);
    });
  });

  group('GlassSheet', () {
    testWidgets('рисует ручку и содержимое на материале bar', (tester) async {
      await pumpGlass(tester, const GlassSheet(child: Text('Лист')));

      expect(tester.widget<GlassSurface>(find.byType(GlassSurface)).material, GlassMaterial.bar);
      expect(find.text('Лист'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('glass-sheet-grabber')), findsOneWidget);
    });

    testWidgets('ручку можно скрыть', (tester) async {
      await pumpGlass(tester, const GlassSheet(showGrabber: false, child: Text('Лист')));

      expect(find.byKey(const ValueKey<String>('glass-sheet-grabber')), findsNothing);
    });
  });

  group('GlassButton', () {
    testWidgets('вызывает onPressed по касанию', (tester) async {
      var taps = 0;
      await pumpGlass(
        tester,
        GlassButton(semanticLabel: 'Далее', onPressed: () => taps++, child: const Icon(CupertinoIcons.add)),
      );

      await tester.tap(find.byType(GlassButton));

      expect(taps, 1);
    });

    testWidgets('тач-зона не меньше 44 pt даже у малого содержимого', (tester) async {
      await pumpGlass(
        tester,
        GlassButton(semanticLabel: 'Далее', onPressed: () {}, child: const SizedBox(width: 8, height: 8)),
      );

      final Size size = tester.getSize(find.byType(GlassButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('без onPressed не реагирует и отмечен как недоступный', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpGlass(
        tester,
        const GlassButton(semanticLabel: 'Далее', onPressed: null, child: Icon(CupertinoIcons.add)),
      );

      final SemanticsNode node = tester.getSemantics(find.bySemanticsLabel('Далее'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('семантика: кнопка с подписью', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpGlass(
        tester,
        GlassButton(semanticLabel: 'Далее', onPressed: () {}, child: const Icon(CupertinoIcons.add)),
      );

      final SemanticsNode node = tester.getSemantics(find.bySemanticsLabel('Далее'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('нажатие подсвечивает кнопку, отпускание снимает подсветку', (tester) async {
      await pumpGlass(
        tester,
        GlassButton(semanticLabel: 'Далее', onPressed: () {}, child: const Icon(CupertinoIcons.add)),
      );
      final Finder pressOverlay = find.byKey(const ValueKey<String>('glass-button-pressed'));
      expect(pressOverlay, findsNothing);

      final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(GlassButton)));
      await tester.pump();
      expect(pressOverlay, findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(pressOverlay, findsNothing);
    });

    testWidgets('отмена жеста снимает подсветку и не вызывает onPressed', (tester) async {
      var taps = 0;
      await pumpGlass(
        tester,
        GlassButton(semanticLabel: 'Далее', onPressed: () => taps++, child: const Icon(CupertinoIcons.add)),
      );

      final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(GlassButton)));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 300));
      await gesture.up();
      await tester.pump();

      expect(taps, 0);
      expect(find.byKey(const ValueKey<String>('glass-button-pressed')), findsNothing);
    });

    testWidgets('плотный вариант по умолчанию для кнопок над схемой доступен параметром', (tester) async {
      await pumpGlass(
        tester,
        GlassButton(
          semanticLabel: 'Далее',
          density: GlassDensity.dense,
          onPressed: () {},
          child: const Icon(CupertinoIcons.add),
        ),
      );

      expect(tester.widget<GlassSurface>(find.byType(GlassSurface)).density, GlassDensity.dense);
    });
  });
}
