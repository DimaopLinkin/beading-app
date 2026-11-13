import 'package:beading/domain/floss_stock/floss_shortage.dart';
import 'package:beading/domain/floss_stock/floss_stock_entry.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

FlossPurchaseLine purchase(String code, double meters, {double reserve = 0.1, String brand = 'DMC'}) =>
    FlossPurchaseLine(
      ref: CatalogRef(brand: brand, code: code),
      rgb: const Rgb(0, 0, 0),
      name: null,
      strandMeters: meters,
      strandMetersWithReserve: meters * (1 + reserve),
      skeins: (meters / 48).ceil(),
      skeinsWithReserve: (meters * (1 + reserve) / 48).ceil(),
    );

FlossStockEntry stock(String code, double skeins, {String brand = 'DMC'}) => FlossStockEntry(
  ref: CatalogRef(brand: brand, code: code),
  skeins: skeins,
);

void main() {
  test('без запаса нужно купить всё нужное число мотков', () {
    final FlossShortage result = FlossShortage.compute(<FlossPurchaseLine>[
      purchase('310', 100),
    ], const <FlossStockEntry>[]);

    expect(result.lines.single.haveSkeins, 0);
    expect(result.lines.single.needSkeins, closeTo(100 / 48, 1e-9));
    expect(result.lines.single.toBuy, 3);
    expect(result.totalToBuy, 3);
    expect(result.isCovered, isFalse);
  });

  test('запас вычитается долями мотка, докупают целые мотки', () {
    final FlossShortage result = FlossShortage.compute(
      <FlossPurchaseLine>[purchase('310', 100)],
      <FlossStockEntry>[stock('310', 1.5)],
    );

    // Нужно 2,08 мотка, есть 1,5: не хватает 0,58 → один моток.
    expect(result.lines.single.toBuy, 1);
    expect(result.lines.single.shortSkeins, closeTo(100 / 48 - 1.5, 1e-9));
  });

  test('хватает, если запас не меньше нужного; докупать нечего', () {
    final FlossShortage result = FlossShortage.compute(
      <FlossPurchaseLine>[purchase('310', 48)],
      <FlossStockEntry>[stock('310', 1)],
    );

    expect(result.lines.single.toBuy, 0);
    expect(result.lines.single.isCovered, isTrue);
    expect(result.isCovered, isTrue);
    expect(result.totalToBuy, 0);
    expect(result.missingCount, 0);
  });

  test('ровные метры из-за double не дают лишний моток', () {
    final FlossShortage result = FlossShortage.compute(
      <FlossPurchaseLine>[purchase('310', 48 * 0.7 * 1 / 0.7)],
      <FlossStockEntry>[stock('310', 1)],
    );

    expect(result.lines.single.toBuy, 0);
  });

  test('бренд учитывается: DMC 310 и Anchor 310 — разные нитки', () {
    final FlossShortage result = FlossShortage.compute(
      <FlossPurchaseLine>[purchase('310', 48)],
      <FlossStockEntry>[stock('310', 5, brand: 'Anchor')],
    );

    expect(result.lines.single.haveSkeins, 0);
    expect(result.lines.single.toBuy, 1);
  });

  test('withReserve считает по метрам с запасом', () {
    final FlossShortage plain = FlossShortage.compute(<FlossPurchaseLine>[
      purchase('310', 48),
    ], const <FlossStockEntry>[]);
    final FlossShortage reserve = FlossShortage.compute(
      <FlossPurchaseLine>[purchase('310', 48)],
      const <FlossStockEntry>[],
      withReserve: true,
    );

    expect(plain.totalToBuy, 1);
    expect(reserve.totalToBuy, 2);
  });

  test('missingCount — сколько ниток не хватает, shoppingLines — только их', () {
    final FlossShortage result = FlossShortage.compute(
      <FlossPurchaseLine>[purchase('310', 48), purchase('666', 96), purchase('700', 10)],
      <FlossStockEntry>[stock('310', 1), stock('666', 1)],
    );

    expect(result.missingCount, 2);
    expect(result.shoppingLines.map((l) => l.purchase.ref.code), <String>['666', '700']);
    expect(result.totalToBuy, 2);
  });
}
