import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BeadSize', () {
    test('содержит Delica 15/0, 11/0, 10/0 и рокайль 15/0, 11/0, 8/0', () {
      expect(BeadSize.values, <BeadSize>[
        BeadSize.delica15,
        BeadSize.delica11,
        BeadSize.delica10,
        BeadSize.rocaille15,
        BeadSize.rocaille11,
        BeadSize.rocaille8,
      ]);
    });

    test('у всех размеров положительные размеры и вес, длина не больше диаметра', () {
      for (final BeadSize size in BeadSize.values) {
        expect(size.diameterMm, greaterThan(0), reason: '$size');
        expect(size.holeLengthMm, greaterThan(0), reason: '$size');
        expect(size.weightGrams, greaterThan(0), reason: '$size');
        expect(size.holeLengthMm, lessThanOrEqualTo(size.diameterMm), reason: '$size');
      }
    });

    test('имя состоит из формы и размера', () {
      expect(BeadSize.delica10.shape, BeadShape.delica);
      expect(BeadSize.delica10.sizeCode, '10/0');
      expect(BeadSize.rocaille8.shape, BeadShape.rocaille);
      expect(BeadSize.rocaille8.sizeCode, '8/0');
    });

    test('цилиндр Delica почти квадратный, у рокайля длина заметно меньше диаметра', () {
      expect(BeadSize.delica11.holeLengthMm / BeadSize.delica11.diameterMm, greaterThan(0.75));
      expect(BeadSize.rocaille11.holeLengthMm / BeadSize.rocaille11.diameterMm, lessThan(0.75));
    });

    test('Delica уже рокайля того же номера по диаметру', () {
      expect(BeadSize.delica11.diameterMm, lessThan(BeadSize.rocaille11.diameterMm));
    });

    test('как CellMetrics: ширина — длина вдоль отверстия, высота — диаметр', () {
      const CellMetrics metrics = BeadSize.rocaille11;

      expect(metrics.widthMm, BeadSize.rocaille11.holeLengthMm);
      expect(metrics.heightMm, BeadSize.rocaille11.diameterMm);
    });

    test('размеры с разными значениями не равны, одинаковые равны', () {
      expect(BeadSize.delica11 == BeadSize.delica11, isTrue);
      expect(BeadSize.delica11 == BeadSize.delica10, isFalse);
    });
  });
}
