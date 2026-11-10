import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

/// Эталонные пары Sharma, Wu, Dalal (2005), таблица 1: L1 a1 b1, L2 a2 b2, ΔE00.
const List<List<double>> _sharma = <List<double>>[
  <double>[50.0000, 2.6772, -79.7751, 50.0000, 0.0000, -82.7485, 2.0425],
  <double>[50.0000, 3.1571, -77.2803, 50.0000, 0.0000, -82.7485, 2.8615],
  <double>[50.0000, 2.8361, -74.0200, 50.0000, 0.0000, -82.7485, 3.4412],
  <double>[50.0000, -1.3802, -84.2814, 50.0000, 0.0000, -82.7485, 1.0000],
  <double>[50.0000, -1.1848, -84.8006, 50.0000, 0.0000, -82.7485, 1.0000],
  <double>[50.0000, -0.9009, -85.5211, 50.0000, 0.0000, -82.7485, 1.0000],
  <double>[50.0000, 0.0000, 0.0000, 50.0000, -1.0000, 2.0000, 2.3669],
  <double>[50.0000, -1.0000, 2.0000, 50.0000, 0.0000, 0.0000, 2.3669],
  <double>[50.0000, 2.4900, -0.0010, 50.0000, -2.4900, 0.0009, 7.1792],
  <double>[50.0000, 2.4900, -0.0010, 50.0000, -2.4900, 0.0010, 7.1792],
  <double>[50.0000, 2.4900, -0.0010, 50.0000, -2.4900, 0.0011, 7.2195],
  <double>[50.0000, 2.4900, -0.0010, 50.0000, -2.4900, 0.0012, 7.2195],
  <double>[50.0000, -0.0010, 2.4900, 50.0000, 0.0009, -2.4900, 4.8045],
  <double>[50.0000, -0.0010, 2.4900, 50.0000, 0.0010, -2.4900, 4.8045],
  <double>[50.0000, -0.0010, 2.4900, 50.0000, 0.0011, -2.4900, 4.7461],
  <double>[50.0000, 2.5000, 0.0000, 50.0000, 0.0000, -2.5000, 4.3065],
  <double>[50.0000, 2.5000, 0.0000, 73.0000, 25.0000, -18.0000, 27.1492],
  <double>[50.0000, 2.5000, 0.0000, 61.0000, -5.0000, 29.0000, 22.8977],
  <double>[50.0000, 2.5000, 0.0000, 56.0000, -27.0000, -3.0000, 31.9030],
  <double>[50.0000, 2.5000, 0.0000, 58.0000, 24.0000, 15.0000, 19.4535],
  <double>[50.0000, 2.5000, 0.0000, 50.0000, 3.1736, 0.5854, 1.0000],
  <double>[50.0000, 2.5000, 0.0000, 50.0000, 3.2972, 0.0000, 1.0000],
  <double>[50.0000, 2.5000, 0.0000, 50.0000, 1.8634, 0.5757, 1.0000],
  <double>[50.0000, 2.5000, 0.0000, 50.0000, 3.2592, 0.3350, 1.0000],
  <double>[60.2574, -34.0099, 36.2677, 60.4626, -34.1751, 39.4387, 1.2644],
  <double>[63.0109, -31.0961, -5.8663, 62.8187, -29.7946, -4.0864, 1.2630],
  <double>[61.2901, 3.7196, -5.3901, 61.4292, 2.2480, -4.9620, 1.8731],
  <double>[35.0831, -44.1164, 3.7933, 35.0232, -40.0716, 1.5901, 1.8645],
  <double>[22.7233, 20.0904, -46.6940, 23.0331, 14.9730, -42.5619, 2.0373],
  <double>[36.4612, 47.8580, 18.3852, 36.2715, 50.5065, 21.2231, 1.4146],
  <double>[90.8027, -2.0831, 1.4410, 91.1528, -1.6435, 0.0447, 1.4441],
  <double>[90.9257, -0.5406, -0.9208, 88.6381, -0.8985, -0.7239, 1.5381],
  <double>[6.7747, -0.2908, -2.4247, 5.8714, -0.0985, -2.2286, 0.6377],
  <double>[2.0776, 0.0795, -1.1350, 0.9033, -0.0636, -0.5514, 0.9082],
];

void main() {
  group('Rgb', () {
    test('отвергает компоненты вне 0..255', () {
      expect(() => Rgb(256, 0, 0), throwsA(isA<AssertionError>()));
      expect(() => Rgb(0, -1, 0), throwsA(isA<AssertionError>()));
    });

    test('hex в обе стороны', () {
      expect(const Rgb(255, 128, 0).hex, '#FF8000');
      expect(Rgb.fromHex('#ff8000'), const Rgb(255, 128, 0));
      expect(Rgb.fromHex('0A0B0C'), const Rgb(10, 11, 12));
    });

    test('fromHex отвергает мусор', () {
      expect(() => Rgb.fromHex('#12345'), throwsFormatException);
      expect(() => Rgb.fromHex('#GGGGGG'), throwsFormatException);
    });

    test('среднее одного цвета — он сам', () {
      expect(Rgb.average(const <Rgb>[Rgb(10, 200, 30)]), const Rgb(10, 200, 30));
    });

    test('среднее чёрного и белого считается в линейном RGB, а не по значениям', () {
      // Линейное 0.5 → sRGB 188 (а не 128 при усреднении гамма-значений).
      expect(Rgb.average(const <Rgb>[Rgb(0, 0, 0), Rgb(255, 255, 255)]), const Rgb(188, 188, 188));
    });

    test('среднее двух цветов не зависит от порядка', () {
      const Rgb a = Rgb(200, 30, 60);
      const Rgb b = Rgb(10, 120, 250);
      expect(Rgb.average(const <Rgb>[a, b]), Rgb.average(const <Rgb>[b, a]));
    });

    test('среднее пустого списка — ошибка', () {
      expect(() => Rgb.average(const <Rgb>[]), throwsArgumentError);
    });
  });

  group('Lab', () {
    test('чёрный и белый', () {
      final Lab black = Lab.fromRgb(const Rgb(0, 0, 0));
      final Lab white = Lab.fromRgb(const Rgb(255, 255, 255));
      expect(black.l, closeTo(0, 1e-6));
      expect(white.l, closeTo(100, 1e-2));
      expect(white.a, closeTo(0, 1e-2));
      expect(white.b, closeTo(0, 1e-2));
    });

    test('красный sRGB (D65)', () {
      final Lab red = Lab.fromRgb(const Rgb(255, 0, 0));
      expect(red.l, closeTo(53.24, 0.05));
      expect(red.a, closeTo(80.09, 0.05));
      expect(red.b, closeTo(67.20, 0.05));
    });

    test('серые имеют нулевой цветовой тон', () {
      final Lab grey = Lab.fromRgb(const Rgb(119, 119, 119));
      expect(grey.l, closeTo(50, 0.2));
      expect(grey.a.abs(), lessThan(0.01));
      expect(grey.b.abs(), lessThan(0.01));
    });
  });

  group('deltaE2000', () {
    for (final List<double> row in _sharma) {
      test('Sharma ${row.sublist(0, 6)} → ${row[6]}', () {
        final Lab a = Lab(row[0], row[1], row[2]);
        final Lab b = Lab(row[3], row[4], row[5]);
        expect(deltaE2000(a, b), closeTo(row[6], 1e-4));
        expect(deltaE2000(b, a), closeTo(row[6], 1e-4), reason: 'симметрия');
      });
    }

    test('одинаковые цвета — ноль', () {
      final Lab a = Lab.fromRgb(const Rgb(10, 20, 30));
      expect(deltaE2000(a, a), 0);
    });

    test('не падает на всём кубе грубой сетки и неотрицательна', () {
      for (int r = 0; r < 256; r += 51) {
        for (int g = 0; g < 256; g += 51) {
          for (int b = 0; b < 256; b += 51) {
            final double d = deltaE2000(Lab.fromRgb(Rgb(r, g, b)), Lab.fromRgb(Rgb(b, r, g)));
            expect(d.isFinite && d >= 0, isTrue);
          }
        }
      }
    });
  });
}
