import 'dart:ui';

import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_policy.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glass_harness.dart';

const Key _fillKey = ValueKey<String>('glass-fill');

Color _fill(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(find.byKey(_fillKey));
  return (box.decoration as ShapeDecoration).color!;
}

void main() {
  const GlassSurface surface = GlassSurface(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    child: SizedBox(width: 100, height: 60),
  );

  group('GlassSurface', () {
    testWidgets('рисует размытие фона, заливку, блик и ребёнка', (tester) async {
      await pumpGlass(tester, const GlassSurface(shape: StadiumBorder(), child: Text('Привет')));

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byKey(_fillKey), findsOneWidget);
      expect(find.text('Привет'), findsOneWidget);
    });

    testWidgets('размытие берёт из токенов материала', (tester) async {
      await pumpGlass(tester, surface);

      final BackdropFilter filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      final double sigma = AppTokensData.standard.glassSurface.blurSigma;
      expect(filter.filter, ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp));
    });

    testWidgets('материал bar использует токены glassBar', (tester) async {
      await pumpGlass(
        tester,
        const GlassSurface(material: GlassMaterial.bar, shape: StadiumBorder(), child: SizedBox()),
      );

      final BackdropFilter filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      final double sigma = AppTokensData.standard.glassBar.blurSigma;
      expect(filter.filter, ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp));
    });

    testWidgets('заливка полупрозрачна в обычном режиме и берётся из тонировки темы', (tester) async {
      await pumpGlass(tester, surface);
      expect(_fill(tester), AppTokensData.standard.glassSurface.tint.color);

      await pumpGlass(tester, surface, brightness: Brightness.dark);
      expect(_fill(tester), AppTokensData.standard.glassSurface.tint.darkColor);
    });

    testWidgets('плотный вариант заливки темнее обычного (для текста поверх ярких цветов)', (tester) async {
      await pumpGlass(
        tester,
        const GlassSurface(density: GlassDensity.dense, shape: StadiumBorder(), child: SizedBox()),
      );

      expect(_fill(tester), AppTokensData.standard.glassSurface.denseTint.color);
      expect(_fill(tester).a, greaterThanOrEqualTo(0.85));
    });

    testWidgets('«Уменьшить прозрачность»: непрозрачная заливка и без размытия', (tester) async {
      await pumpGlass(
        tester,
        const GlassPolicy(
          reduceTransparency: true,
          child: GlassSurface(shape: StadiumBorder(), child: SizedBox()),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(_fill(tester), AppTokensData.standard.glassSurface.opaqueFill.color);
      expect(_fill(tester).a, 1);
    });

    testWidgets('повышенная контрастность включает непрозрачный вариант без политики', (tester) async {
      await pumpGlass(tester, surface, highContrast: true, brightness: Brightness.dark);

      expect(find.byType(BackdropFilter), findsNothing);
      expect(_fill(tester), AppTokensData.standard.glassSurface.opaqueFill.darkColor);
    });

    testWidgets('политика без «Уменьшить прозрачность» оставляет стекло', (tester) async {
      await pumpGlass(tester, const GlassPolicy(reduceTransparency: false, child: surface));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('содержимое изолировано RepaintBoundary, чтобы размытие не перерисовывало сетку', (tester) async {
      await pumpGlass(tester, surface);

      expect(
        find.descendant(of: find.byType(GlassSurface), matching: find.byType(RepaintBoundary)),
        findsWidgets,
      );
    });

    testWidgets('блик и заливка не перехватывают касания', (tester) async {
      var taps = 0;
      await pumpGlass(
        tester,
        GestureDetector(onTap: () => taps++, child: surface),
      );

      await tester.tap(find.byType(GlassSurface));
      expect(taps, 1);
    });
  });

  group('GlassPolicy', () {
    testWidgets('по умолчанию прозрачность не уменьшена', (tester) async {
      late bool opaque;
      await pumpGlass(
        tester,
        Builder(
          builder: (context) {
            opaque = GlassPolicy.isOpaque(context);
            return const SizedBox();
          },
        ),
      );

      expect(opaque, isFalse);
    });

    testWidgets('обновляет зависимых при смене флага', (tester) async {
      final ValueNotifier<bool> reduce = ValueNotifier<bool>(false);
      addTearDown(reduce.dispose);
      await pumpGlass(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: reduce,
          builder: (context, value, _) => GlassPolicy(reduceTransparency: value, child: surface),
        ),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);

      reduce.value = true;
      await tester.pump();

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}
