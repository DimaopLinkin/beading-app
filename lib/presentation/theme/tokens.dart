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
    required this.xxxl,
  });

  final double xs;
  final double s;
  final double m;
  final double l;
  final double xl;
  final double xxl;
  final double xxxl;
}

/// Радиусы скруглений. Крупные, в духе Liquid Glass. Вложенные формы концентричны: внутренний радиус = внешний минус
/// отступ ([xl] и [concentricInner] для панели 30 с вложенной кнопкой 22).
@immutable
class RadiusTokens {
  const RadiusTokens({
    required this.s,
    required this.m,
    required this.l,
    required this.xl,
    required this.concentricInner,
    required this.capsule,
  });

  final double s;
  final double m;
  final double l;

  /// Внешний радиус концентричной пары (панель).
  final double xl;

  /// Внутренний радиус концентричной пары (кнопка в панели).
  final double concentricInner;

  /// Капсула: радиус заведомо больше половины любой высоты.
  final double capsule;
}

/// Параметры материала «стекло» (Liquid Glass): размытие фона, тонировка, граница и блик.
/// Сами эффекты рисуют виджеты `presentation/widgets/glass/`; здесь только значения, одинаково реализуемые на iOS и macOS.
///
/// [tint] — обычное стекло (тулбары, табы, баннеры); [denseTint] — плотное, для текста поверх ярких цветов бусин.
/// Для «Уменьшить прозрачность» и повышенной контрастности: [opaqueFill] и [opaqueDenseFill] с заметными границами
/// [opaqueBorder] и [opaqueDenseBorder] (контраст границы к фону экрана не ниже 3:1).
@immutable
class GlassTokens {
  const GlassTokens({
    required this.blurSigma,
    required this.denseBlurSigma,
    required this.tint,
    required this.border,
    required this.highlight,
    required this.denseTint,
    required this.opaqueFill,
    required this.opaqueBorder,
    required this.opaqueDenseFill,
    required this.opaqueDenseBorder,
    this.borderWidth = 1,
    this.opaqueBorderWidth = 1.5,
  });

  final double blurSigma;

  /// Размытие плотного стекла.
  final double denseBlurSigma;
  final CupertinoDynamicColor tint;
  final CupertinoDynamicColor border;
  final CupertinoDynamicColor highlight;
  final CupertinoDynamicColor denseTint;
  final CupertinoDynamicColor opaqueFill;

  /// Заметная граница непрозрачного варианта (повышенная контрастность).
  final CupertinoDynamicColor opaqueBorder;
  final CupertinoDynamicColor opaqueDenseFill;
  final CupertinoDynamicColor opaqueDenseBorder;
  final double borderWidth;
  final double opaqueBorderWidth;
}

/// Цвета ролей. Источник: UI kit (Main.dc.html) и дополнение 01b (контраст проверен тестом).
@immutable
class ColorTokens {
  const ColorTokens({
    required this.background,
    required this.surface,
    required this.surface2,
    required this.content,
    required this.contentSecondary,
    required this.separator,
    required this.accent,
    required this.accentPressed,
    required this.onAccent,
    required this.accentText,
    required this.accentFill,
    required this.wave,
    required this.statusIdea,
    required this.statusIdeaFill,
    required this.statusInProgress,
    required this.statusInProgressFill,
    required this.statusDone,
    required this.statusDoneFill,
    required this.danger,
    required this.onDanger,
  });

  /// Фон экрана.
  final CupertinoDynamicColor background;

  /// Карточки, листы.
  final CupertinoDynamicColor surface;

  /// Поля, чипы, нажатое.
  final CupertinoDynamicColor surface2;

  /// Основной текст.
  final CupertinoDynamicColor content;

  /// Подписи.
  final CupertinoDynamicColor contentSecondary;

  /// Линии-разделители.
  final CupertinoDynamicColor separator;

  /// «Янтарь»: основные действия (не текст).
  final CupertinoDynamicColor accent;
  final CupertinoDynamicColor accentPressed;

  /// Текст и иконки на [accent].
  final CupertinoDynamicColor onAccent;

  /// Акцент для текста на фоне и поверхности (светлая тема темнее [accent]).
  final CupertinoDynamicColor accentText;

  /// Тинт акцента: выбранный инструмент, текущий ряд.
  final CupertinoDynamicColor accentFill;

  /// Второй акцент «Волна»: выбор, ссылки.
  final CupertinoDynamicColor wave;
  final CupertinoDynamicColor statusIdea;
  final CupertinoDynamicColor statusIdeaFill;
  final CupertinoDynamicColor statusInProgress;
  final CupertinoDynamicColor statusInProgressFill;
  final CupertinoDynamicColor statusDone;
  final CupertinoDynamicColor statusDoneFill;
  final CupertinoDynamicColor danger;
  final CupertinoDynamicColor onDanger;
}

/// Типографика (шрифт системный, размеры следуют Dynamic Type). Цвет не задан: берётся из темы.
@immutable
class TypographyTokens {
  const TypographyTokens({
    required this.display,
    required this.title1,
    required this.title2,
    required this.headline,
    required this.body,
    required this.callout,
    required this.caption,
    required this.counter,
    this.counterMaxScale = 1.35,
    this.minFontSize = 13,
  });

  final TextStyle display;
  final TextStyle title1;
  final TextStyle title2;
  final TextStyle headline;
  final TextStyle body;
  final TextStyle callout;

  /// Подпись, не меньше [minFontSize].
  final TextStyle caption;

  /// Счётчик ряда: 40 pt, моноширинные цифры. Это данные, а не текст: растёт с Dynamic Type до [counterMaxScale]
  /// (54 pt), дальше фиксирован; см. [AppTokensData.counterTextScaler].
  final TextStyle counter;
  final double counterMaxScale;

  /// Ни один текст в приложении не мельче этого размера.
  final double minFontSize;
}

/// Двойное кольцо вокруг текущего ряда: внутреннее почти чёрное, внешнее белое. Различимо на любых бусинах и фонах
/// (01b, п. 3). Дополнительно слева рисуется маркер с номером ряда в капсуле акцента.
@immutable
class RowRingTokens {
  const RowRingTokens({
    required this.inner,
    required this.outer,
    this.innerWidth = 2,
    this.outerWidth = 2.5,
    this.edgeWidth = 1,
  }) : assert(innerWidth > 0, 'innerWidth должен быть положительным');

  final Color inner;
  final Color outer;
  final double innerWidth;
  final double outerWidth;

  /// Внешняя тонкая линия того же цвета, что [inner].
  final double edgeWidth;
}

/// Все токены дизайна в одном месте. Значения перенесены из UI kit (T01b): `docs/design/accepted/01-ui-kit`
/// и `01b-ui-kit-addendum`.
@immutable
class AppTokensData {
  const AppTokensData({
    required this.spacing,
    required this.radius,
    required this.colors,
    required this.typography,
    required this.accent,
    required this.rowHighlight,
    required this.rowDim,
    required this.rowRing,
    required this.glassSurface,
    required this.glassBar,
    this.minTapTarget = 44,
    this.disabledOpacity = 0.4,
    this.pressedScale = 0.97,
  });

  /// «Янтарь»: основной акцент (см. [ColorTokens.accent]).
  static const CupertinoDynamicColor accentColor = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFB5541C),
    darkColor: Color(0xFFF0955A),
  );

  static const ColorTokens _colors = ColorTokens(
    background: CupertinoDynamicColor.withBrightness(color: Color(0xFFF7F4EF), darkColor: Color(0xFF151316)),
    surface: CupertinoDynamicColor.withBrightness(color: Color(0xFFFFFFFF), darkColor: Color(0xFF201D22)),
    surface2: CupertinoDynamicColor.withBrightness(color: Color(0xFFEFEBE4), darkColor: Color(0xFF2A262D)),
    content: CupertinoDynamicColor.withBrightness(color: Color(0xFF1C1A1F), darkColor: Color(0xFFF4F0EA)),
    contentSecondary: CupertinoDynamicColor.withBrightness(color: Color(0xFF5F5954), darkColor: Color(0xFFA9A29B)),
    separator: CupertinoDynamicColor.withBrightness(color: Color(0xFFE0DAD1), darkColor: Color(0xFF3A353D)),
    accent: accentColor,
    accentPressed: CupertinoDynamicColor.withBrightness(color: Color(0xFF97440F), darkColor: Color(0xFFD77F47)),
    onAccent: CupertinoDynamicColor.withBrightness(color: Color(0xFFFFFFFF), darkColor: Color(0xFF1C1A1F)),
    accentText: CupertinoDynamicColor.withBrightness(color: Color(0xFF9A4513), darkColor: Color(0xFFF0955A)),
    accentFill: CupertinoDynamicColor.withBrightness(color: Color(0x29B5541C), darkColor: Color(0x3DF0955A)),
    wave: CupertinoDynamicColor.withBrightness(color: Color(0xFF1F7A7A), darkColor: Color(0xFF5FC4BF)),
    statusIdea: CupertinoDynamicColor.withBrightness(color: Color(0xFF4A52A6), darkColor: Color(0xFF9BA3EE)),
    statusIdeaFill: CupertinoDynamicColor.withBrightness(color: Color(0x245B63B7), darkColor: Color(0x2E9BA3EE)),
    statusInProgress: CupertinoDynamicColor.withBrightness(color: Color(0xFF8A5300), darkColor: Color(0xFFF2B84B)),
    statusInProgressFill: CupertinoDynamicColor.withBrightness(
      color: Color(0x29A86A00),
      darkColor: Color(0x2EF2B84B),
    ),
    statusDone: CupertinoDynamicColor.withBrightness(color: Color(0xFF27704A), darkColor: Color(0xFF6FCF97)),
    statusDoneFill: CupertinoDynamicColor.withBrightness(color: Color(0x262E7D4F), darkColor: Color(0x2E6FCF97)),
    danger: CupertinoDynamicColor.withBrightness(color: Color(0xFFC0362C), darkColor: Color(0xFFFF7A6E)),
    onDanger: CupertinoDynamicColor.withBrightness(color: Color(0xFFFFFFFF), darkColor: Color(0xFF1C1A1F)),
  );

  static const TypographyTokens _typography = TypographyTokens(
    display: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.4),
    title1: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.3),
    title2: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.2),
    headline: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
    body: TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
    callout: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
    caption: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.1),
    counter: TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w600,
      letterSpacing: -1,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
  );

  static const GlassTokens _glass = GlassTokens(
    blurSigma: 24,
    denseBlurSigma: 32,
    // Обычное: белое 55% / #28262C 50%. Плотное: белое 84% / #1C1A20 82%.
    tint: CupertinoDynamicColor.withBrightness(color: Color(0x8CFFFFFF), darkColor: Color(0x8028262C)),
    denseTint: CupertinoDynamicColor.withBrightness(color: Color(0xD6FFFFFF), darkColor: Color(0xD11C1A20)),
    border: CupertinoDynamicColor.withBrightness(color: Color(0xD9FFFFFF), darkColor: Color(0x42FFFFFF)),
    highlight: CupertinoDynamicColor.withBrightness(color: Color(0xCCFFFFFF), darkColor: Color(0x47FFFFFF)),
    opaqueFill: CupertinoDynamicColor.withBrightness(color: Color(0xFFFBF9F5), darkColor: Color(0xFF2A262D)),
    opaqueBorder: CupertinoDynamicColor.withBrightness(color: Color(0xFF8F8880), darkColor: Color(0xFF8D8791)),
    opaqueDenseFill: CupertinoDynamicColor.withBrightness(color: Color(0xFFFFFFFF), darkColor: Color(0xFF34303A)),
    opaqueDenseBorder: CupertinoDynamicColor.withBrightness(color: Color(0xFF6E6760), darkColor: Color(0xFFA8A2AD)),
  );

  static const AppTokensData standard = AppTokensData(
    spacing: SpacingTokens(xs: 4, s: 8, m: 12, l: 16, xl: 24, xxl: 32, xxxl: 48),
    radius: RadiusTokens(s: 8, m: 16, l: 24, xl: 30, concentricInner: 22, capsule: 999),
    colors: _colors,
    typography: _typography,
    accent: accentColor,
    // Заливка текущего ряда тинтом акцента.
    rowHighlight: CupertinoDynamicColor.withBrightness(color: Color(0x29B5541C), darkColor: Color(0x2EF0955A)),
    // Вуаль цвета фона 62% поверх пройденных рядов.
    rowDim: CupertinoDynamicColor.withBrightness(color: Color(0x9EF7F4EF), darkColor: Color(0x9E151316)),
    rowRing: RowRingTokens(inner: Color(0xFF151316), outer: Color(0xFFFFFFFF)),
    glassSurface: _glass,
    glassBar: _glass,
  );

  final SpacingTokens spacing;
  final RadiusTokens radius;
  final ColorTokens colors;
  final TypographyTokens typography;

  /// Акцентный цвет приложения.
  final CupertinoDynamicColor accent;

  /// Заливка текущего ряда.
  final CupertinoDynamicColor rowHighlight;

  /// Вуаль на пройденных рядах.
  final CupertinoDynamicColor rowDim;

  /// Двойное кольцо вокруг текущего ряда.
  final RowRingTokens rowRing;

  final GlassTokens glassSurface;
  final GlassTokens glassBar;

  /// Минимальная тач-зона, pt.
  final double minTapTarget;

  /// Прозрачность выключенных элементов (исключение WCAG для неактивных).
  final double disabledOpacity;

  /// Масштаб нажатого элемента (плавающие кнопки и кнопки инструментов нажимаются сильнее, до 0,92).
  final double pressedScale;

  /// Стиль цифр счётчика: 40 pt, моноширинные цифры. Шрифт системный.
  TextStyle get counterTextStyle => typography.counter;

  /// Масштаб текста счётчика: следует Dynamic Type до [TypographyTokens.counterMaxScale], дальше не растёт.
  TextScaler counterTextScaler(TextScaler system) => system.clamp(maxScaleFactor: typography.counterMaxScale);
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
