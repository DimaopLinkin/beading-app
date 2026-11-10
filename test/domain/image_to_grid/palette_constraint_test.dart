import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/image_to_grid/palette_constraint.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';

void main() {
  final List<CatalogColor> catalog = <CatalogColor>[
    catalogColor('DB0001', 'Black', '#000000'),
    catalogColor('DB0002', 'White', '#FFFFFF', series: 'Round'),
    catalogColor('B5', 'Red', '#FF0000', brand: 'Toho'),
    catalogColor('310', 'Black thread', '#000000', brand: 'DMC', material: CatalogMaterial.floss),
  ];

  group('PaletteConstraint', () {
    test('свободная палитра не ограничивает', () {
      const PaletteConstraint constraint = PaletteConstraint.free();

      expect(constraint.isFree, isTrue);
      expect(constraint.candidates, isNull);
    });

    test('каталог отбирает только нужный материал', () {
      final PaletteConstraint constraint = PaletteConstraint.catalog(catalog, material: CatalogMaterial.floss);

      expect(constraint.candidates!.map((e) => e.catalog!.code), <String>['310']);
    });

    test('каталог фильтрует по бренду и серии', () {
      final PaletteConstraint byBrand = PaletteConstraint.catalog(
        catalog,
        material: CatalogMaterial.bead,
        brands: <String>{'Miyuki'},
      );
      final PaletteConstraint bySeries = PaletteConstraint.catalog(
        catalog,
        material: CatalogMaterial.bead,
        series: <String>{'Round'},
      );

      expect(byBrand.candidates!.map((e) => e.catalog!.code), <String>['DB0001', 'DB0002']);
      expect(bySeries.candidates!.map((e) => e.catalog!.code), <String>['DB0002']);
    });

    test('каталог фильтрует по размеру бисера', () {
      final PaletteConstraint eleven = PaletteConstraint.catalog(
        catalog,
        material: CatalogMaterial.bead,
        sizeCodes: <String>{'11/0'},
      );
      final PaletteConstraint fifteen = PaletteConstraint.catalog(
        catalog,
        material: CatalogMaterial.bead,
        sizeCodes: <String>{'15/0'},
      );

      expect(eleven.candidates, hasLength(3));
      expect(fifteen.candidates, isEmpty);
    });

    test('цвет записи каталога — её собственный RGB', () {
      final PaletteEntry entry = PaletteEntry.fromCatalog(catalog.first);

      expect(entry.rgb, const Rgb(0, 0, 0));
      expect(entry.catalog, catalog.first);
    });

    test('список копируется и неизменяем', () {
      final List<PaletteEntry> source = <PaletteEntry>[const PaletteEntry(rgb: Rgb(1, 2, 3))];
      final PaletteConstraint constraint = PaletteConstraint.list(source);

      source.clear();

      expect(constraint.candidates, hasLength(1));
      expect(() => constraint.candidates!.add(const PaletteEntry(rgb: Rgb(0, 0, 0))), throwsUnsupportedError);
    });
  });
}
