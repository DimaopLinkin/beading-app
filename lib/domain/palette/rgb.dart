import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Цвет sRGB, 8 бит на канал.
final class Rgb extends Equatable {
  const Rgb(this.r, this.g, this.b)
    : assert(r >= 0 && r <= 255, 'r вне 0..255'),
      assert(g >= 0 && g <= 255, 'g вне 0..255'),
      assert(b >= 0 && b <= 255, 'b вне 0..255');

  /// Разбирает `#RRGGBB` или `RRGGBB`.
  factory Rgb.fromHex(String hex) {
    final String digits = hex.startsWith('#') ? hex.substring(1) : hex;
    if (!_hexPattern.hasMatch(digits)) {
      throw FormatException('Ожидался цвет RRGGBB', hex);
    }
    final int value = int.parse(digits, radix: 16);
    return Rgb((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF);
  }

  /// Среднее цветов в линейном RGB (физически верное смешение света, а не усреднение гамма-значений).
  ///
  /// Так считается цвет смешанной нити мулине (две нитки в иголке).
  factory Rgb.average(List<Rgb> colors) {
    if (colors.isEmpty) {
      throw ArgumentError.value(colors, 'colors', 'нужен хотя бы один цвет');
    }
    double r = 0;
    double g = 0;
    double b = 0;
    for (final Rgb c in colors) {
      r += _toLinear(c.r);
      g += _toLinear(c.g);
      b += _toLinear(c.b);
    }
    final int n = colors.length;
    return Rgb(_fromLinear(r / n), _fromLinear(g / n), _fromLinear(b / n));
  }

  static final RegExp _hexPattern = RegExp(r'^[0-9a-fA-F]{6}$');

  final int r;
  final int g;
  final int b;

  /// `#RRGGBB` заглавными.
  String get hex => '#${_two(r)}${_two(g)}${_two(b)}';

  /// Линейные компоненты 0..1 (для перехода в XYZ).
  (double, double, double) get linear => (_toLinear(r), _toLinear(g), _toLinear(b));

  static String _two(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();

  static double _toLinear(int c) {
    final double s = c / 255;
    return s <= 0.04045 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  static int _fromLinear(double l) {
    final double s = l <= 0.0031308 ? l * 12.92 : 1.055 * math.pow(l, 1 / 2.4).toDouble() - 0.055;
    return (s * 255).round().clamp(0, 255);
  }

  @override
  List<Object?> get props => <Object?>[r, g, b];

  @override
  String toString() => 'Rgb($hex)';
}
