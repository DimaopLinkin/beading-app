import 'dart:math' as math;

import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

double _channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) => 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double _contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Контраст пар цветов из таблицы 01b (WCAG): текст не ниже 4,5:1, не текст (кнопки, кольца, границы) не ниже 3:1.
void main() {
  const AppTokensData t = AppTokensData.standard;
  final ColorTokens c = AppTokensData.standard.colors;

  for (final Brightness brightness in Brightness.values) {
    final bool light = brightness == Brightness.light;
    Color pick(CupertinoDynamicColor color) => light ? color.color : color.darkColor;
    Color over(CupertinoDynamicColor fill, CupertinoDynamicColor base) => Color.alphaBlend(pick(fill), pick(base));

    group('контраст, ${brightness.name}', () {
      final Map<String, (Color, Color)> text = <String, (Color, Color)>{
        'контент / фон': (pick(c.content), pick(c.background)),
        'контент / поверхность': (pick(c.content), pick(c.surface)),
        'вторичный / фон': (pick(c.contentSecondary), pick(c.background)),
        'вторичный / поверхность': (pick(c.contentSecondary), pick(c.surface)),
        'вторичный / поверхность 2': (pick(c.contentSecondary), pick(c.surface2)),
        'текст на акценте': (pick(c.onAccent), pick(c.accent)),
        'акцент-текст / фон': (pick(c.accentText), pick(c.background)),
        'акцент-текст / поверхность': (pick(c.accentText), pick(c.surface)),
        '«Волна» / поверхность': (pick(c.wave), pick(c.surface)),
        'удаление / поверхность': (pick(c.danger), pick(c.surface)),
        'текст на кнопке удаления': (pick(c.onDanger), pick(c.danger)),
        'статус «идея» / заливка': (pick(c.statusIdea), over(c.statusIdeaFill, c.surface)),
        'статус «в работе» / заливка': (pick(c.statusInProgress), over(c.statusInProgressFill, c.surface)),
        'статус «готово» / заливка': (pick(c.statusDone), over(c.statusDoneFill, c.surface)),
        'контент на непрозрачном стекле': (pick(c.content), pick(t.glassSurface.opaqueFill)),
        'контент на непрозрачном плотном стекле': (pick(c.content), pick(t.glassSurface.opaqueDenseFill)),
      };
      for (final MapEntry<String, (Color, Color)> e in text.entries) {
        test('текст: ${e.key} не ниже 4,5:1', () {
          expect(_contrast(e.value.$1, e.value.$2), greaterThanOrEqualTo(4.5));
        });
      }

      final Map<String, (Color, Color)> nonText = <String, (Color, Color)>{
        'акцент / поверхность': (pick(c.accent), pick(c.surface)),
        'граница непрозрачного стекла / фон': (pick(t.glassSurface.opaqueBorder), pick(c.background)),
        'граница непрозрачного плотного стекла / фон': (pick(t.glassSurface.opaqueDenseBorder), pick(c.background)),
      };
      for (final MapEntry<String, (Color, Color)> e in nonText.entries) {
        test('не текст: ${e.key} не ниже 3:1', () {
          expect(_contrast(e.value.$1, e.value.$2), greaterThanOrEqualTo(3));
        });
      }
    });
  }

  group('кольцо текущего ряда различимо на любых бусинах', () {
    for (final Color bead in const <Color>[
      Color(0xFFF2B84B),
      Color(0xFFE8833A),
      Color(0xFFF4F0EA),
      Color(0xFFF06A5A),
    ]) {
      test('внутреннее кольцо / бусина $bead не ниже 3:1', () {
        expect(_contrast(t.rowRing.inner, bead), greaterThanOrEqualTo(3));
      });
    }

    test('внешнее кольцо отделяется от внутреннего', () {
      expect(_contrast(t.rowRing.outer, t.rowRing.inner), greaterThanOrEqualTo(3));
    });
  });

  test('граница непрозрачного стекла 1,5 pt (как в макете 01b)', () {
    expect(t.glassSurface.opaqueBorderWidth, 1.5);
  });

  test('ни один размер шрифта в токенах не меньше 13 pt', () {
    final TypographyTokens ty = t.typography;
    for (final TextStyle s in <TextStyle>[
      ty.display,
      ty.title1,
      ty.title2,
      ty.headline,
      ty.body,
      ty.callout,
      ty.caption,
      ty.counter,
    ]) {
      expect(s.fontSize, greaterThanOrEqualTo(ty.minFontSize));
    }
  });

  test('счётчик ряда: 40 pt, растёт с Dynamic Type до ×1,35 и дальше не растёт', () {
    expect(t.typography.counter.fontSize, 40);
    expect(t.counterTextScaler(TextScaler.noScaling).scale(40), 40);
    expect(t.counterTextScaler(const TextScaler.linear(1.2)).scale(40), closeTo(48, 1e-9));
    expect(t.counterTextScaler(const TextScaler.linear(2.2)).scale(40), closeTo(54, 1e-9));
  });
}
