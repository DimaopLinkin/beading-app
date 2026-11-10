import 'dart:math' as math;

import 'package:beading/domain/palette/rgb.dart';
import 'package:equatable/equatable.dart';

/// Цвет в CIE L*a*b* (белая точка D65).
final class Lab extends Equatable {
  const Lab(this.l, this.a, this.b);

  /// sRGB → линейный RGB → XYZ (D65) → Lab.
  factory Lab.fromRgb(Rgb rgb) {
    final (double r, double g, double b) = rgb.linear;
    final double x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b;
    final double y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b;
    final double z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b;
    final double fx = _f(x / _xn);
    final double fy = _f(y / _yn);
    final double fz = _f(z / _zn);
    return Lab(116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
  }

  /// Lab → XYZ (D65) → линейный RGB → sRGB; значения вне гаммы обрезаются.
  Rgb toRgb() {
    final double fy = (l + 16) / 116;
    final double fx = fy + a / 500;
    final double fz = fy - b / 200;
    final double x = _xn * _fInverse(fx);
    final double y = _yn * _fInverse(fy);
    final double z = _zn * _fInverse(fz);
    final double r = 3.2404542 * x - 1.5371385 * y - 0.4985314 * z;
    final double g = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z;
    final double bl = 0.0556434 * x - 0.2040259 * y + 1.0572252 * z;
    return Rgb(_toSrgb(r), _toSrgb(g), _toSrgb(bl));
  }

  /// Точка между [from] и [to]: [t] от 0 до 1, по прямой в Lab.
  factory Lab.lerp(Lab from, Lab to, double t) =>
      Lab(from.l + (to.l - from.l) * t, from.a + (to.a - from.a) * t, from.b + (to.b - from.b) * t);

  static double _fInverse(double t) {
    const double delta = 6 / 29;
    return t > delta ? t * t * t : 3 * delta * delta * (t - 4 / 29);
  }

  static int _toSrgb(double linear) {
    final double c = linear.clamp(0, 1).toDouble();
    final double s = c <= 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;
    return (s * 255).round().clamp(0, 255);
  }

  static const double _xn = 0.95047;
  static const double _yn = 1;
  static const double _zn = 1.08883;

  static double _f(double t) {
    const double delta = 6 / 29;
    return t > delta * delta * delta ? math.pow(t, 1 / 3).toDouble() : t / (3 * delta * delta) + 4 / 29;
  }

  final double l;
  final double a;
  final double b;

  @override
  List<Object?> get props => <Object?>[l, a, b];

  @override
  String toString() => 'Lab($l, $a, $b)';
}

/// Цветовое различие CIEDE2000 (Sharma, Wu, Dalal, 2005) с kL = kC = kH = 1.
double deltaE2000(Lab c1, Lab c2) {
  final double cBar = (math.sqrt(c1.a * c1.a + c1.b * c1.b) + math.sqrt(c2.a * c2.a + c2.b * c2.b)) / 2;
  final double cBar7 = math.pow(cBar, 7).toDouble();
  final double g = 0.5 * (1 - math.sqrt(cBar7 / (cBar7 + _pow25to7)));
  final double a1p = (1 + g) * c1.a;
  final double a2p = (1 + g) * c2.a;
  final double c1p = math.sqrt(a1p * a1p + c1.b * c1.b);
  final double c2p = math.sqrt(a2p * a2p + c2.b * c2.b);
  final double h1p = _hue(c1.b, a1p);
  final double h2p = _hue(c2.b, a2p);

  final double dLp = c2.l - c1.l;
  final double dCp = c2p - c1p;
  double dhp = 0;
  if (c1p * c2p != 0) {
    dhp = h2p - h1p;
    if (dhp > 180) {
      dhp -= 360;
    } else if (dhp < -180) {
      dhp += 360;
    }
  }
  final double dHp = 2 * math.sqrt(c1p * c2p) * math.sin(_rad(dhp) / 2);

  final double lBarP = (c1.l + c2.l) / 2;
  final double cBarP = (c1p + c2p) / 2;
  double hBarP;
  if (c1p * c2p == 0) {
    hBarP = h1p + h2p;
  } else if ((h1p - h2p).abs() <= 180) {
    hBarP = (h1p + h2p) / 2;
  } else if (h1p + h2p < 360) {
    hBarP = (h1p + h2p + 360) / 2;
  } else {
    hBarP = (h1p + h2p - 360) / 2;
  }

  final double t =
      1 -
      0.17 * math.cos(_rad(hBarP - 30)) +
      0.24 * math.cos(_rad(2 * hBarP)) +
      0.32 * math.cos(_rad(3 * hBarP + 6)) -
      0.20 * math.cos(_rad(4 * hBarP - 63));
  final double dTheta = 30 * math.exp(-math.pow((hBarP - 275) / 25, 2).toDouble());
  final double cBarP7 = math.pow(cBarP, 7).toDouble();
  final double rc = 2 * math.sqrt(cBarP7 / (cBarP7 + _pow25to7));
  final double lm50 = (lBarP - 50) * (lBarP - 50);
  final double sl = 1 + 0.015 * lm50 / math.sqrt(20 + lm50);
  final double sc = 1 + 0.045 * cBarP;
  final double sh = 1 + 0.015 * cBarP * t;
  final double rt = -math.sin(_rad(2 * dTheta)) * rc;

  final double lTerm = dLp / sl;
  final double cTerm = dCp / sc;
  final double hTerm = dHp / sh;
  return math.sqrt(lTerm * lTerm + cTerm * cTerm + hTerm * hTerm + rt * cTerm * hTerm);
}

final double _pow25to7 = math.pow(25, 7).toDouble();

double _rad(double degrees) => degrees * math.pi / 180;

/// Угол оттенка в градусах 0..360 (0 при a = b = 0).
double _hue(double b, double a) {
  if (b == 0 && a == 0) {
    return 0;
  }
  final double h = math.atan2(b, a) * 180 / math.pi;
  return h < 0 ? h + 360 : h;
}
