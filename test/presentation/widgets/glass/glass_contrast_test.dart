import 'dart:math' as math;

import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// Контраст (WCAG) текста; размытие и блик не учитываются (они лишь сглаживают фон). Обычный tint не проверяется: для текста над схемой нужен dense.
/// Контраст (WCAG) текста поверх плотного стекла над самыми «тяжёлыми» цветами бусин.
double _luminance(Color c) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const List<Color> extremeBeads = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFFFFFF00),
    Color(0xFFFF0000),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
  ];

  final Map<String, GlassTokens> materials = <String, GlassTokens>{
    'surface': AppTokensData.standard.glassSurface,
    'bar': AppTokensData.standard.glassBar,
  };
  for (final MapEntry<String, GlassTokens> material in materials.entries) {
    for (final Brightness brightness in Brightness.values) {
      test('текст на плотном стекле читается поверх любых цветов бусин, ${material.key}, ${brightness.name}', () {
        final bool light = brightness == Brightness.light;
        final CupertinoDynamicColor tintToken = material.value.denseTint;
        final Color tint = light ? tintToken.color : tintToken.darkColor;
        final Color label = light ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

        for (final Color bead in extremeBeads) {
          final Color shown = Color.alphaBlend(tint, bead);
          expect(_contrast(label, shown), greaterThanOrEqualTo(4.5), reason: 'бусина $bead');
        }
      });

      test('непрозрачный вариант контрастен с текстом, ${material.key}, ${brightness.name}', () {
        final bool light = brightness == Brightness.light;
        final CupertinoDynamicColor token = material.value.opaqueFill;
        final Color fill = light ? token.color : token.darkColor;
        final Color label = light ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

        expect(_contrast(label, fill), greaterThanOrEqualTo(7));
      });
    }
  }
}
