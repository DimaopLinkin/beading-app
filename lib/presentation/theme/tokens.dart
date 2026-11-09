import 'package:flutter/cupertino.dart';

/// Отступы. Растут строго монотонно.
@immutable
class SpacingTokens {
  const SpacingTokens({
    required this.xs,
    required this.s,
    required this.m,
    required this.l,
    required this.xl,
    required this.xxl,
  });

  final double xs;
  final double s;
  final double m;
  final double l;
  final double xl;
  final double xxl;
}

/// Радиусы скруглений. Крупные, в духе Liquid Glass.
@immutable
class RadiusTokens {
  const RadiusTokens({required this.s, required this.m, required this.l, required this.xl});

  final double s;
  final double m;
  final double l;
  final double xl;
}

/// Параметры материала «стекло» (Liquid Glass): размытие фона, тонировка, граница и блик.
/// Сами эффекты рисуют виджеты T01g; здесь только значения, одинаково реализуемые на iOS и macOS.
@immutable
class GlassTokens {
  const GlassTokens({
    required this.blurSigma,
    required this.tint,
    required this.border,
    required this.highlight,
    this.borderWidth = 0.5,
  });

  final double blurSigma;
  final CupertinoDynamicColor tint;
  final CupertinoDynamicColor border;
  final CupertinoDynamicColor highlight;
  final double borderWidth;
}

/// Все токены дизайна в одном месте: T01b заменит значения, а не структуру.
@immutable
class AppTokensData {
  const AppTokensData({
    required this.spacing,
    required this.radius,
    required this.accent,
    required this.rowHighlight,
    required this.rowDim,
    required this.glassSurface,
    required this.glassBar,
    required this.counterTextStyle,
    this.minTapTarget = 44,
  });

  static const CupertinoDynamicColor accentColor = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF8E4EC6),
    darkColor: Color(0xFFB57EDC),
  );

  /// Временные значения до переноса UI kit (T01b).
  static const AppTokensData standard = AppTokensData(
    spacing: SpacingTokens(xs: 4, s: 8, m: 12, l: 16, xl: 24, xxl: 32),
    radius: RadiusTokens(s: 10, m: 16, l: 24, xl: 32),
    accent: accentColor,
    rowHighlight: CupertinoDynamicColor.withBrightness(
      color: Color(0x66FFD60A),
      darkColor: Color(0x80FFD60A),
    ),
    rowDim: CupertinoDynamicColor.withBrightness(
      color: Color(0xB3F2F2F7),
      darkColor: Color(0xB31C1C1E),
    ),
    glassSurface: GlassTokens(
      blurSigma: 24,
      tint: CupertinoDynamicColor.withBrightness(color: Color(0x80FFFFFF), darkColor: Color(0x661C1C1E)),
      border: CupertinoDynamicColor.withBrightness(color: Color(0x33000000), darkColor: Color(0x26FFFFFF)),
      highlight: CupertinoDynamicColor.withBrightness(color: Color(0xCCFFFFFF), darkColor: Color(0x33FFFFFF)),
    ),
    glassBar: GlassTokens(
      blurSigma: 30,
      tint: CupertinoDynamicColor.withBrightness(color: Color(0xB3FFFFFF), darkColor: Color(0xB31C1C1E)),
      border: CupertinoDynamicColor.withBrightness(color: Color(0x4D000000), darkColor: Color(0x33FFFFFF)),
      highlight: CupertinoDynamicColor.withBrightness(color: Color(0xE6FFFFFF), darkColor: Color(0x40FFFFFF)),
    ),
    counterTextStyle: TextStyle(fontFeatures: <FontFeature>[FontFeature.tabularFigures()]),
  );

  final SpacingTokens spacing;
  final RadiusTokens radius;

  /// Акцентный цвет приложения.
  final CupertinoDynamicColor accent;

  /// Подсветка текущего ряда.
  final CupertinoDynamicColor rowHighlight;

  /// Притушение остальных рядов.
  final CupertinoDynamicColor rowDim;

  final GlassTokens glassSurface;
  final GlassTokens glassBar;

  /// Стиль цифр счётчика: моноширинные цифры, чтобы число не «прыгало». Шрифт системный.
  final TextStyle counterTextStyle;

  /// Минимальная тач-зона, pt.
  final double minTapTarget;
}

/// Раздаёт [AppTokensData] вниз по дереву: `context.tokens`.
class AppTokens extends InheritedWidget {
  const AppTokens({required this.data, required super.child, super.key});

  final AppTokensData data;

  static AppTokensData of(BuildContext context) {
    final AppTokens? scope = context.dependOnInheritedWidgetOfExactType<AppTokens>();
    assert(scope != null, 'AppTokens не найден в дереве: оберните приложение в AppTheme.builder');
    return scope!.data;
  }

  @override
  bool updateShouldNotify(AppTokens oldWidget) => data != oldWidget.data;
}

extension AppTokensContext on BuildContext {
  AppTokensData get tokens => AppTokens.of(this);
}
