import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const CatalogColor color = CatalogColor(
    material: CatalogMaterial.bead,
    brand: 'Miyuki',
    series: 'Delica',
    code: 'DB0010',
    name: 'Black',
    rgb: Rgb(0, 0, 0),
    sizeCode: '11/0',
  );

  test('id стабилен и включает размер', () => expect(color.id, 'bead|Miyuki|Delica|11/0|DB0010'));

  test('ref — бренд и артикул', () {
    expect(color.ref.brand, 'Miyuki');
    expect(color.ref.code, 'DB0010');
  });

  test('материал разбирается из строки', () {
    expect(CatalogMaterial.fromWire('floss'), CatalogMaterial.floss);
    expect(CatalogMaterial.fromWire('x'), isNull);
  });
}
