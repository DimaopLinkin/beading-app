import 'package:beading/domain/image_pattern/book_work/ruler_state.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';

/// Цвета подсветки линейки: полупрозрачные, чтобы схема под ними читалась. Края полосы рисует двойное кольцо
/// (`RowRing`), а «жёлтый» по умолчанию теперь тинт акцента «Янтарь» из UI kit.
abstract final class RulerColors {
  static const CupertinoDynamicColor _green = CupertinoDynamicColor.withBrightness(
    color: Color(0x6634C759),
    darkColor: Color(0x8030D158),
  );
  static const CupertinoDynamicColor _blue = CupertinoDynamicColor.withBrightness(
    color: Color(0x660A84FF),
    darkColor: Color(0x80409CFF),
  );
  static const CupertinoDynamicColor _pink = CupertinoDynamicColor.withBrightness(
    color: Color(0x66FF375F),
    darkColor: Color(0x80FF6482),
  );

  /// Заливка полосы линейки.
  static Color fill(BuildContext context, RulerHighlight highlight) =>
      CupertinoDynamicColor.resolve(switch (highlight) {
        RulerHighlight.yellow => context.tokens.rowHighlight,
        RulerHighlight.green => _green,
        RulerHighlight.blue => _blue,
        RulerHighlight.pink => _pink,
      }, context);

  /// Непрозрачный образец для выбора цвета и границ линейки.
  static Color swatch(BuildContext context, RulerHighlight highlight) => switch (highlight) {
    RulerHighlight.yellow => context.tokens.accent,
    RulerHighlight.green => CupertinoColors.systemGreen,
    RulerHighlight.blue => CupertinoColors.systemBlue,
    RulerHighlight.pink => CupertinoColors.systemPink,
  }.resolveFrom(context);
}
