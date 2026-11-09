import 'package:beading/presentation/theme/app_theme.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppTokensData> tokensIn(WidgetTester tester, Brightness brightness) async {
    late AppTokensData tokens;
    await tester.pumpWidget(
      CupertinoApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        builder: AppTheme.builder,
        home: Builder(
          builder: (context) {
            tokens = context.tokens;
            return const SizedBox();
          },
        ),
      ),
    );
    return tokens;
  }

  testWidgets('токены доступны через context.tokens', (tester) async {
    expect(await tokensIn(tester, Brightness.light), same(AppTokensData.standard));
  });

  testWidgets('без AppTokens в дереве context.tokens падает с понятной ошибкой', (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          context.tokens;
          return const SizedBox();
        },
      ),
    );

    expect(tester.takeException(), isA<AssertionError>());
  });

  group('цвета подсветки и притушения ряда', () {
    testWidgets('резолвятся по яркости темы', (tester) async {
      for (final Brightness b in Brightness.values) {
        late Color highlight;
        late Color dim;
        await tester.pumpWidget(
          CupertinoApp(
            theme: b == Brightness.light ? AppTheme.light : AppTheme.dark,
            builder: AppTheme.builder,
            home: Builder(
              builder: (context) {
                highlight = CupertinoDynamicColor.resolve(context.tokens.rowHighlight, context);
                dim = CupertinoDynamicColor.resolve(context.tokens.rowDim, context);
                return const SizedBox();
              },
            ),
          ),
        );
        const AppTokensData t = AppTokensData.standard;
        expect(
          highlight.toARGB32(),
          (b == Brightness.light ? t.rowHighlight.color : t.rowHighlight.darkColor).toARGB32(),
        );
        expect(dim.toARGB32(), (b == Brightness.light ? t.rowDim.color : t.rowDim.darkColor).toARGB32());
      }
    });

    test('различаются между светлой и тёмной темой', () {
      const AppTokensData t = AppTokensData.standard;
      expect(t.rowHighlight.color, isNot(t.rowHighlight.darkColor));
      expect(t.rowDim.color, isNot(t.rowDim.darkColor));
    });

    test('притушение полупрозрачное, подсветка заметна', () {
      const AppTokensData t = AppTokensData.standard;
      expect(t.rowDim.color.a, lessThan(1));
      expect(t.rowHighlight.color.a, greaterThan(0));
    });
  });

  group('материал стекла (Liquid Glass)', () {
    test('размытие положительное, тонировка полупрозрачная в обеих темах', () {
      for (final GlassTokens g in <GlassTokens>[AppTokensData.standard.glassSurface, AppTokensData.standard.glassBar]) {
        expect(g.blurSigma, greaterThan(0));
        expect(g.tint.color.a, inInclusiveRange(0.01, 0.99));
        expect(g.tint.darkColor.a, inInclusiveRange(0.01, 0.99));
        expect(g.borderWidth, greaterThan(0));
        expect(g.border.color, isNot(g.border.darkColor));
        expect(g.highlight.color.a, greaterThan(0));
      }
    });

    test('панель плотнее поверхности: читаемость текста важнее прозрачности', () {
      const AppTokensData t = AppTokensData.standard;
      expect(t.glassBar.tint.color.a, greaterThanOrEqualTo(t.glassSurface.tint.color.a));
    });
  });

  group('радиусы и отступы', () {
    test('радиусы растут и крупнее материальных', () {
      final RadiusTokens r = AppTokensData.standard.radius;
      expect(
        <double>[r.s, r.m, r.l, r.xl],
        orderedEquals(
          <double>[
            ...<double>[r.s, r.m, r.l, r.xl],
          ]..sort(),
        ),
      );
      expect(r.m, greaterThanOrEqualTo(16));
      expect(r.l, greaterThanOrEqualTo(24));
    });

    test('отступы строго растут, тач-зона не меньше 44', () {
      final SpacingTokens s = AppTokensData.standard.spacing;
      final List<double> values = <double>[s.xs, s.s, s.m, s.l, s.xl, s.xxl];
      for (int i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
      expect(AppTokensData.standard.minTapTarget, greaterThanOrEqualTo(44));
    });
  });

  test('цифры счётчика — моноширинные (tabular figures)', () {
    final TextStyle style = AppTokensData.standard.counterTextStyle;
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  test('шрифт системный: нигде не задан fontFamily', () {
    expect(AppTokensData.standard.counterTextStyle.fontFamily, isNull);
    expect(AppTheme.light.textTheme.textStyle.fontFamily, anyOf(isNull, startsWith('.SF'), 'CupertinoSystemText'));
  });
}
