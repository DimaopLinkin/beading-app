import 'package:flutter/cupertino.dart';

/// Цвета схемы поверх бусин. Двойное кольцо текущего ряда берётся из токена `rowRing`.
abstract final class GridColors {
  /// Вуаль на пройденных рядах: цвет фона при 62% непрозрачности.
  static const CupertinoDynamicColor veil = CupertinoDynamicColor.withBrightness(
    color: Color(0x9EF7F4EF),
    darkColor: Color(0x9E151316),
  );

  /// Тонкая линия сетки. Видна и на светлом, и на тёмном фоне.
  static const CupertinoDynamicColor line = CupertinoDynamicColor.withBrightness(
    color: Color(0x40000000),
    darkColor: Color(0x4DFFFFFF),
  );

  /// Жирная линия «каждая N-я».
  static const CupertinoDynamicColor boldLine = CupertinoDynamicColor.withBrightness(
    color: Color(0xCC1C1A1F),
    darkColor: Color(0xCCF4F0EA),
  );

  /// Контур пустой ячейки.
  static const CupertinoDynamicColor emptyCell = CupertinoDynamicColor.withBrightness(
    color: Color(0x14000000),
    darkColor: Color(0x1FFFFFFF),
  );

  /// Заливка для индекса, которого нет в палитре.
  static const CupertinoDynamicColor unknown = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC7C7CC),
    darkColor: Color(0xFF636366),
  );

  /// Цвет знака на бусине: чёрный или белый, по яркости заливки.
  static Color symbolOn(Color fill) =>
      fill.computeLuminance() > 0.45 ? const Color(0xFF151316) : const Color(0xFFFFFFFF);
}
