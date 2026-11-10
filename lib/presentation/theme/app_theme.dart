import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';

/// Тема приложения на Cupertino. Шрифт системный (SF), размер следует Dynamic Type; цвета ролей из UI kit.
abstract final class AppTheme {
  static const CupertinoDynamicColor _content = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF1C1A1F),
    darkColor: Color(0xFFF4F0EA),
  );
  static const CupertinoDynamicColor _scaffold = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF7F4EF),
    darkColor: Color(0xFF151316),
  );

  /// Панель навигации и табов: фон экрана с лёгкой прозрачностью (стеклянный слой рисуют виджеты glass/).
  static const CupertinoDynamicColor _bar = CupertinoDynamicColor.withBrightness(
    color: Color(0xD6F7F4EF),
    darkColor: Color(0xD6151316),
  );

  static const CupertinoTextThemeData _text = CupertinoTextThemeData(
    primaryColor: AppTokensData.accentColor,
    textStyle: TextStyle(
      inherit: false,
      fontFamily: 'CupertinoSystemText',
      fontSize: 17,
      letterSpacing: -0.41,
      color: _content,
      decoration: TextDecoration.none,
    ),
    navTitleTextStyle: TextStyle(
      inherit: false,
      fontFamily: 'CupertinoSystemText',
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.41,
      color: _content,
    ),
    navLargeTitleTextStyle: TextStyle(
      inherit: false,
      fontFamily: 'CupertinoSystemDisplay',
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: _content,
    ),
  );

  /// Яркость берётся из системы.
  static const CupertinoThemeData system = CupertinoThemeData(
    primaryColor: AppTokensData.accentColor,
    scaffoldBackgroundColor: _scaffold,
    barBackgroundColor: _bar,
    textTheme: _text,
  );

  static const CupertinoThemeData light = CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: AppTokensData.accentColor,
    scaffoldBackgroundColor: _scaffold,
    barBackgroundColor: _bar,
    textTheme: _text,
  );

  static const CupertinoThemeData dark = CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: AppTokensData.accentColor,
    scaffoldBackgroundColor: _scaffold,
    barBackgroundColor: _bar,
    textTheme: _text,
  );

  /// Для `CupertinoApp.builder`: кладёт [AppTokens] над экранами.
  static Widget builder(BuildContext context, Widget? child) =>
      AppTokens(data: AppTokensData.standard, child: child ?? const SizedBox.shrink());
}
