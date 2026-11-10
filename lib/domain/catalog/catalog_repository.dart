import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Каталог цветов бисера и ниток (только чтение: наполняется из `assets/catalog`).
abstract interface class CatalogRepository {
  /// Поиск по артикулу (без учёта регистра, дефисов и ведущих нулей) и названию.
  ///
  /// Пустой [query] — всё, что подошло под фильтры, в порядке: бренд, серия, размер, артикул (числа как числа).
  /// С запросом сначала совпадение артикула целиком («10» = «DB-0010»; «45» находит и 45A), затем название.
  Future<Result<List<CatalogColor>>> search({String query = '', CatalogMaterial? material, String? brand});

  /// Бренды материала в алфавитном порядке.
  Future<Result<List<String>>> brands(CatalogMaterial material);

  /// Позиция по ссылке из палитры; `null`, если в каталоге такой нет (например, пользовательский цвет).
  Future<Result<CatalogColor?>> find(String brand, String code);

  /// До [count] ближайших по ΔE2000 к [target]; при `count <= 0` — пустой список.
  Future<Result<List<ColorMatch<CatalogColor>>>> nearest(
    Rgb target, {
    required CatalogMaterial material,
    String? brand,
    int count = 5,
  });
}
