import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/catalog/color_similarity.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:equatable/equatable.dart';

/// Цвет каталога, похожий на выбранный, и мера похожести.
final class SimilarColor extends Equatable {
  const SimilarColor({required this.color, required this.similarity});

  final CatalogColor color;
  final ColorSimilarity similarity;

  @override
  List<Object?> get props => <Object?>[color, similarity];
}

/// «Подобрать похожий»: ближайшие по ΔE2000 цвета каталога к выбранному, без него самого.
///
/// По умолчанию ищет среди всех брендов материала: так находится замена, когда нужного цвета нет в магазине.
final class FindSimilarColors {
  const FindSimilarColors(this._catalog);

  /// Сколько цветов показываем.
  static const int defaultCount = 5;

  final CatalogRepository _catalog;

  /// До [count] цветов, самые близкие первыми. [brand] ограничивает поиск одним брендом.
  Future<Result<List<SimilarColor>>> call(CatalogColor source, {String? brand, int count = defaultCount}) async {
    // На один больше: сам выбранный цвет всегда ближе всех (ΔE = 0) и отбрасывается.
    final Result<List<ColorMatch<CatalogColor>>> found = await _catalog.nearest(
      source.rgb,
      material: source.material,
      brand: brand,
      count: count + 1,
    );
    return found.map(
      (matches) => <SimilarColor>[
        for (final ColorMatch<CatalogColor> match in matches)
          if (match.item.id != source.id) SimilarColor(color: match.item, similarity: ColorSimilarity(match.deltaE)),
      ].take(count).toList(growable: false),
    );
  }
}
