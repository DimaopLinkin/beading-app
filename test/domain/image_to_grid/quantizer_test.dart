import 'package:beading/domain/image_to_grid/quantizer.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

Lab lab(int hex) => Lab.fromRgb(Rgb.fromHex(hex.toRadixString(16).padLeft(6, '0')));

void main() {
  const LabQuantizer quantizer = LabQuantizer();

  group('LabQuantizer', () {
    test('нет точек — нет центров', () {
      final Quantization result = quantizer.quantize(<Lab>[], <double>[], colors: 4);

      expect(result.centers, isEmpty);
      expect(result.assignments, isEmpty);
    });

    test('одинаковые точки дают один центр, сколько бы цветов ни просили', () {
      final List<Lab> points = List<Lab>.filled(10, lab(0x336699));

      final Quantization result = quantizer.quantize(points, List<double>.filled(10, 1), colors: 5);

      expect(result.centers, hasLength(1));
      expect(result.assignments, everyElement(0));
    });

    test('два разных цвета разделяются точно', () {
      final List<Lab> points = <Lab>[lab(0x000000), lab(0xFFFFFF), lab(0x000000), lab(0xFFFFFF)];

      final Quantization result = quantizer.quantize(points, List<double>.filled(4, 1), colors: 2);

      expect(result.centers, hasLength(2));
      expect(result.assignments[0], result.assignments[2]);
      expect(result.assignments[1], result.assignments[3]);
      expect(result.assignments[0], isNot(result.assignments[1]));
      expect(result.centers[result.assignments[0]], lab(0x000000));
    });

    test('центров не больше запрошенного', () {
      final List<Lab> points = <Lab>[for (int i = 0; i < 100; i++) lab(i * 0x020304)];

      for (final int colors in <int>[1, 3, 7, 12]) {
        final Quantization result = quantizer.quantize(points, List<double>.filled(100, 1), colors: colors);

        expect(result.centers.length, lessThanOrEqualTo(colors), reason: '$colors цветов');
        expect(result.assignments.every((a) => a >= 0 && a < result.centers.length), isTrue);
      }
    });

    test('тяжёлые точки сильнее тянут центр', () {
      final List<Lab> points = <Lab>[lab(0x000000), lab(0xFFFFFF)];

      final Quantization light = quantizer.quantize(points, <double>[1, 1], colors: 1);
      final Quantization heavy = quantizer.quantize(points, <double>[1, 9], colors: 1);

      expect(heavy.centers.single.l, greaterThan(light.centers.single.l));
    });

    test('важный цвет получает свой центр, а не поглощается фоном', () {
      // 50 точек фона (оттенки синего) и 2 точки лица: при малом весе лицо слилось бы с фоном.
      final List<Lab> points = <Lab>[
        for (int i = 0; i < 50; i++) lab(0x2030A0 + i),
        lab(0xE0B090),
        lab(0xE0B091),
      ];
      final List<double> weights = <double>[...List<double>.filled(50, 1), 40, 40];

      final Quantization result = quantizer.quantize(points, weights, colors: 2);

      expect(result.assignments[50], isNot(result.assignments[0]));
    });

    test('один вход и одно зерно — один результат', () {
      final List<Lab> points = <Lab>[for (int i = 0; i < 60; i++) lab((i * 0x0B1C2D) & 0xFFFFFF)];
      final List<double> weights = List<double>.filled(60, 1);

      final Quantization a = quantizer.quantize(points, weights, colors: 6, seed: 7);
      final Quantization b = quantizer.quantize(points, weights, colors: 6, seed: 7);

      expect(a.centers, b.centers);
      expect(a.assignments, b.assignments);
    });

    test('неверные аргументы отклоняются', () {
      expect(() => quantizer.quantize(<Lab>[lab(0)], <double>[1], colors: 0), throwsArgumentError);
      expect(() => quantizer.quantize(<Lab>[lab(0)], <double>[], colors: 1), throwsArgumentError);
    });
  });
}
