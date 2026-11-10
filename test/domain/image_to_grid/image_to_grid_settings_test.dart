import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/technique_geometry.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';

void main() {
  final SourceImage image = SourceImage.solid(width: 100, height: 200, r: 10, g: 20, b: 30);
  final List<CatalogColor> catalog = <CatalogColor>[
    catalogColor('DB0010', 'Красный', '#C80A14'),
    catalogColor('DB0011', 'Синий', '#0A14C8'),
    catalogColor('T-1', 'Toho', '#00FF00', brand: 'Toho', series: 'Round'),
    catalogColor('M-1', 'Нитка', '#111111', material: CatalogMaterial.floss),
  ];

  group('geometryForTechnique', () {
    test('пейот и кирпич сдвинуты, остальные ровные', () {
      expect(geometryForTechnique(Technique.peyote), isA<PeyoteGeometry>());
      expect(geometryForTechnique(Technique.brick), isA<BrickGeometry>());
      for (final Technique t in <Technique>[Technique.loom, Technique.square, Technique.offLoom]) {
        expect(geometryForTechnique(t), isA<RectangularGeometry>());
      }
    });
  });

  group('ImageToGridSettings', () {
    test('по умолчанию станок, Delica 11/0, каталог', () {
      const ImageToGridSettings s = ImageToGridSettings();
      expect(s.technique, Technique.loom);
      expect(s.beadSize, BeadSize.delica11);
      expect(s.paletteSource, PaletteSource.catalog);
    });

    test('техники мастера — только бисерные', () {
      expect(ImageToGridSettings.techniques, everyElement(predicate<Technique>((t) => t.craft == Craft.beading)));
    });

    test('copyWith держит ширину и число цветов в границах', () {
      const ImageToGridSettings s = ImageToGridSettings();
      expect(s.copyWith(columns: 1).columns, ImageToGridSettings.minColumns);
      expect(s.copyWith(columns: 99999).columns, ImageToGridSettings.maxColumns);
      expect(s.copyWith(maxColors: 0).maxColors, ImageToGridSettings.minColors);
      expect(s.copyWith(maxColors: 999).maxColors, ImageToGridSettings.maxColorsLimit);
    });

    test('ряды повторяют пропорции картинки', () {
      // Картинка 1:2, ячейка Delica 11/0 чуть выше, чем шире: рядов заметно больше половины ширины в клетках...
      const ImageToGridSettings s = ImageToGridSettings();
      final int rows = s.rowsFor(image);
      expect(rows, greaterThan(40));
      expect(rows, lessThan(100));
    });

    test('каталожные цвета отбираются по бисеру, размеру и бренду', () {
      const ImageToGridSettings s = ImageToGridSettings();
      expect(s.catalogFor(catalog).map((c) => c.code), <String>['DB0010', 'DB0011', 'T-1']);
      expect(s.catalogFor(catalog, brand: 'Miyuki').map((c) => c.code), <String>['DB0010', 'DB0011']);
      expect(s.copyWith(beadSize: BeadSize.delica15).catalogFor(catalog), isEmpty);
    });

    test('запрос с каталогом ограничивает палитру каталогом', () {
      final ImageToGridRequest request = const ImageToGridSettings().toRequest(
        image: image,
        catalog: catalog,
        brand: 'Miyuki',
      );
      expect(request.constraint.isFree, isFalse);
      expect(request.constraint.candidates, hasLength(2));
      expect(request.columns, 40);
      expect(request.rows, const ImageToGridSettings().rowsFor(image));
    });

    test('свободная палитра — без ограничений', () {
      final ImageToGridRequest request = const ImageToGridSettings(
        paletteSource: PaletteSource.free,
      ).toRequest(image: image, catalog: catalog);
      expect(request.constraint.isFree, isTrue);
    });

    test('нет цветов каталога под размер — палитра свободная, а не ошибка', () {
      final ImageToGridRequest request = const ImageToGridSettings(
        beadSize: BeadSize.delica15,
      ).toRequest(image: image, catalog: catalog);
      expect(request.constraint.isFree, isTrue);
    });
  });
}
