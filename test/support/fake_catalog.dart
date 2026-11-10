import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Каталог из двух позиций; поиск — по вхождению запроса в артикул или название.
class FakeCatalogRepository implements CatalogRepository {
  static const CatalogColor red = CatalogColor(
    material: CatalogMaterial.bead,
    brand: 'Miyuki',
    series: 'Delica',
    code: 'DB0010',
    name: 'Красный матовый',
    rgb: Rgb(200, 10, 20),
    sizeCode: '11/0',
  );
  static const CatalogColor blue = CatalogColor(
    material: CatalogMaterial.bead,
    brand: 'Miyuki',
    series: 'Delica',
    code: 'DB0002',
    name: 'Синий',
    rgb: Rgb(0, 0, 200),
    sizeCode: '11/0',
  );

  static const List<CatalogColor> all = <CatalogColor>[red, blue];

  @override
  Future<Result<List<CatalogColor>>> search({String query = '', CatalogMaterial? material, String? brand}) async {
    final String q = query.toLowerCase();
    return Success<List<CatalogColor>>(
      all.where((c) => q.isEmpty || c.code.toLowerCase().contains(q) || c.name.toLowerCase().contains(q)).toList(),
    );
  }

  @override
  Future<Result<List<String>>> brands(CatalogMaterial material) async =>
      const Success<List<String>>(<String>['Miyuki']);

  @override
  Future<Result<CatalogColor?>> find(String brand, String code) async =>
      Success<CatalogColor?>(all.where((c) => c.brand == brand && c.code == code).firstOrNull);

  @override
  Future<Result<List<ColorMatch<CatalogColor>>>> nearest(
    Rgb target, {
    required CatalogMaterial material,
    String? brand,
    int count = 5,
  }) async => Success<List<ColorMatch<CatalogColor>>>(
    all.take(count).map((c) => ColorMatch<CatalogColor>(c, 1)).toList(),
  );
}
