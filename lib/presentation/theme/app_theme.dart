import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';

/// Тема приложения на Cupertino. Шрифт системный (SF), размер следует Dynamic Type.
abstract final class AppTheme {
  static const CupertinoDynamicColor _primary = AppTokensData.accentColor;

  /// Яркость берётся из системы.
  static const CupertinoThemeData system = CupertinoThemeData(primaryColor: _primary);

  static const CupertinoThemeData light = CupertinoThemeData(brightness: Brightness.light, primaryColor: _primary);

  static const CupertinoThemeData dark = CupertinoThemeData(brightness: Brightness.dark, primaryColor: _primary);

  /// Для `CupertinoApp.builder`: кладёт [AppTokens] над экранами.
  static Widget builder(BuildContext context, Widget? child) =>
      AppTokens(data: AppTokensData.standard, child: child ?? const SizedBox.shrink());
}
