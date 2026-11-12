import 'package:beading/core/failure.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fabric.create', () {
    test('Аида 14: клетка 25,4 / 14 мм, квадратная', () {
      final Fabric f = Fabric.create(kind: FabricKind.aida, count: 14).valueOrNull!;
      expect(f, isA<CellMetrics>());
      expect(f.widthMm, closeTo(25.4 / 14, 1e-9));
      expect(f.heightMm, f.widthMm);
      expect(f.stitchesPerInch, 14);
      expect(f.overCount, 1);
    });

    test('равномерка 28 «через 2»: 14 стежков на дюйм, как Аида 14', () {
      final Fabric f = Fabric.create(kind: FabricKind.evenweave, count: 28).valueOrNull!;
      expect(f.overCount, 2);
      expect(f.stitchesPerInch, 14);
      expect(f.widthMm, closeTo(25.4 / 14, 1e-9));
    });

    test('лён 32 «через 1»: клетка вдвое меньше, чем «через 2»', () {
      final Fabric one = Fabric.create(kind: FabricKind.linen, count: 32, overCount: 1).valueOrNull!;
      final Fabric two = Fabric.create(kind: FabricKind.linen, count: 32).valueOrNull!;
      expect(one.widthMm * 2, closeTo(two.widthMm, 1e-9));
    });

    test('Аида: плотность 11–20, «через» только 1', () {
      expect(Fabric.create(kind: FabricKind.aida, count: 10).failureOrNull, isA<ValidationFailure>());
      expect(Fabric.create(kind: FabricKind.aida, count: 21).failureOrNull, isA<ValidationFailure>());
      expect(Fabric.create(kind: FabricKind.aida, count: 11).isSuccess, isTrue);
      expect(Fabric.create(kind: FabricKind.aida, count: 20).isSuccess, isTrue);
      expect(Fabric.create(kind: FabricKind.aida, count: 14, overCount: 2).failureOrNull, isA<ValidationFailure>());
    });

    test('равномерка и лён: плотность 25–36, «через» 1 или 2', () {
      for (final FabricKind kind in <FabricKind>[FabricKind.evenweave, FabricKind.linen]) {
        expect(Fabric.create(kind: kind, count: 24).failureOrNull, isA<ValidationFailure>());
        expect(Fabric.create(kind: kind, count: 37).failureOrNull, isA<ValidationFailure>());
        expect(Fabric.create(kind: kind, count: 25).isSuccess, isTrue);
        expect(Fabric.create(kind: kind, count: 36).isSuccess, isTrue);
        expect(Fabric.create(kind: kind, count: 28, overCount: 3).failureOrNull, isA<ValidationFailure>());
      }
    });

    test('цвет канвы по умолчанию белый и сохраняется', () {
      expect(Fabric.create(kind: FabricKind.aida, count: 14).valueOrNull!.color, const Rgb(255, 255, 255));
      final Fabric f = Fabric.create(kind: FabricKind.aida, count: 14, color: const Rgb(10, 20, 30)).valueOrNull!;
      expect(f.color, const Rgb(10, 20, 30));
    });
  });

  group('размер в сантиметрах и клетках', () {
    final Fabric aida14 = Fabric.create(kind: FabricKind.aida, count: 14).valueOrNull!;

    test('10 см на Аида 14 — 55 клеток (14 на дюйм = 5,51 на см)', () {
      expect(aida14.cellsForCm(10), 55);
    });

    test('обратно: 55 клеток — 9,96 см', () {
      expect(aida14.cmForCells(55), closeTo(55 * 2.54 / 14, 1e-9));
    });

    test('на более плотной канве то же число клеток занимает меньше места', () {
      final Fabric aida18 = Fabric.create(kind: FabricKind.aida, count: 18).valueOrNull!;
      expect(aida18.cmForCells(100), lessThan(aida14.cmForCells(100)));
      expect(aida18.cellsForCm(20), greaterThan(aida14.cellsForCm(20)));
    });

    test('не меньше одной клетки; нечисловой или неположительный размер — ошибка аргумента', () {
      expect(aida14.cellsForCm(0.01), 1);
      expect(() => aida14.cellsForCm(0), throwsArgumentError);
      expect(() => aida14.cellsForCm(double.nan), throwsArgumentError);
      expect(() => aida14.cmForCells(0), throwsArgumentError);
      expect(() => aida14.cmForCells(-5), throwsArgumentError);
      expect(() => aida14.cellsForCm(-1), throwsArgumentError);
    });
  });

  group('крестиков на сантиметр и запас ткани', () {
    test('Аида 14: 5,51 крестика на см; Аида 18: 7,09', () {
      expect(aida14.stitchesPerCm, closeTo(14 / 2.54, 1e-9));
      expect(Fabric.create(kind: FabricKind.aida, count: 18).valueOrNull!.stitchesPerCm, closeTo(18 / 2.54, 1e-9));
    });

    test('равномерка 28 «через 2» даёт столько же крестиков, сколько Аида 14', () {
      final Fabric even = Fabric.create(kind: FabricKind.evenweave, count: 28).valueOrNull!;
      expect(even.stitchesPerCm, closeTo(aida14.stitchesPerCm, 1e-9));
      expect(even.cellsForCm(20), aida14.cellsForCm(20));
    });

    test('ткань берут с запасом по 5 см с каждой стороны', () {
      expect(Fabric.allowanceCm, 5);
      expect(aida14.fabricCmFor(100), closeTo(100 * 2.54 / 14 + 10, 1e-9));
    });
  });

  group('сложения по умолчанию от канвы', () {
    int cross(int count, {FabricKind kind = FabricKind.aida, int over = 1}) =>
        Fabric.create(kind: kind, count: count, overCount: over).valueOrNull!.defaultCrossStrands;
    int back(int count) => Fabric.create(kind: FabricKind.aida, count: count).valueOrNull!.defaultBackstitchStrands;

    test('крестик: 11 — 3 нити, 14–18 — 2, 20 — 1', () {
      expect(cross(11), 3);
      expect(cross(14), 2);
      expect(cross(18), 2);
      expect(cross(20), 1);
    });

    test('считаем по стежкам на дюйм: равномерка 28 через 2 — как Аида 14', () {
      expect(cross(28, kind: FabricKind.evenweave, over: 2), 2);
      expect(cross(32, kind: FabricKind.linen), 1);
    });

    test('границы: 12 и 18 — две нити, 19 — одна; равномерка 25 через 2 — 12,5 стежка на дюйм, две нити', () {
      expect(cross(12), 2);
      expect(cross(18), 2);
      expect(cross(19), 1);
      final Fabric f = Fabric.create(kind: FabricKind.evenweave, count: 25).valueOrNull!;
      expect(f.stitchesPerInch, 12.5);
      expect(f.defaultCrossStrands, 2);
    });

    test('бэкстич: на крупной канве две нити, иначе одна', () {
      expect(back(11), 2);
      expect(back(14), 1);
    });
  });

  test('равенство по значению', () {
    expect(
      Fabric.create(kind: FabricKind.aida, count: 14).valueOrNull,
      Fabric.create(kind: FabricKind.aida, count: 14).valueOrNull,
    );
    expect(
      Fabric.create(kind: FabricKind.aida, count: 14).valueOrNull,
      isNot(Fabric.create(kind: FabricKind.aida, count: 16).valueOrNull),
    );
  });
}
