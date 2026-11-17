import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:equatable/equatable.dart';

/// Из каких цветов можно собирать схему.
///
/// Равенство по значению: два запроса с одним списком допустимых цветов дают один ключ кеша стадий (T58).
///
/// Три режима: свободно ([PaletteConstraint.free]), только каталог выбранного материала и бренда
/// ([PaletteConstraint.catalog]) и заданный список ([PaletteConstraint.list]), например запасы бисера.
final class PaletteConstraint extends Equatable {
  /// Любые цвета: палитра берётся из самой картинки.
  const PaletteConstraint.free() : candidates = null, preferredBrand = null, foreignPenaltyDeltaE = 0;

  /// Только позиции каталога, подходящие по материалу, брендам, сериям и размеру бисера.
  ///
  /// Пустой [brands], [series], [sizeCodes] или [finishes] не ограничивает; позиция с неизвестной отделкой проходит.
  ///
  /// [preferredBrand] — основной бренд (T86): нитки других брендов в списке считаются запасными и берутся в палитру,
  /// только если ближе основной на [foreignPenaltyDeltaE] и больше.
  factory PaletteConstraint.catalog(
    Iterable<CatalogColor> colors, {
    required CatalogMaterial material,
    Set<String> brands = const <String>{},
    Set<String> series = const <String>{},
    Set<String> sizeCodes = const <String>{},
    Set<String> finishes = const <String>{},
    String? preferredBrand,
    double foreignPenaltyDeltaE = defaultForeignPenaltyDeltaE,
  }) => PaletteConstraint.list(
    <PaletteEntry>[
      for (final CatalogColor color in colors)
        if (color.material == material &&
            (brands.isEmpty || brands.contains(color.brand)) &&
            (series.isEmpty || series.contains(color.series)) &&
            (sizeCodes.isEmpty || (color.sizeCode != null && sizeCodes.contains(color.sizeCode))) &&
            (finishes.isEmpty || color.finish == null || finishes.contains(color.finish)))
          PaletteEntry.fromCatalog(color),
    ],
    preferredBrand: preferredBrand,
    foreignPenaltyDeltaE: foreignPenaltyDeltaE,
  );

  /// Только цвета из списка. Пустой список — ошибка: из ничего схему не собрать.
  PaletteConstraint.list(
    List<PaletteEntry> entries, {
    this.preferredBrand,
    this.foreignPenaltyDeltaE = defaultForeignPenaltyDeltaE,
  }) : candidates = List<PaletteEntry>.unmodifiable(entries);

  /// Штраф чужой нитки по умолчанию, ΔE2000: заметная глазу разница, но меньше типичного шага каталога.
  static const double defaultForeignPenaltyDeltaE = 3;

  /// Допустимые цвета или `null`, если ограничений нет.
  final List<PaletteEntry>? candidates;

  /// Основной бренд (T86) или `null`, если все позиции равноправны.
  final String? preferredBrand;

  /// Чужая нитка берётся, только если она ближе своей больше чем на столько (ΔE2000). Прибавляется к расстоянию
  /// позиций не основного бренда при выборе ниток в палитру; раскладка клеток по готовой палитре штрафа не знает.
  final double foreignPenaltyDeltaE;

  /// Штраф позиции [entry] к расстоянию: [foreignPenaltyDeltaE] у нитки не основного бренда, иначе 0.
  double penaltyOf(PaletteEntry entry) {
    final String? brand = preferredBrand;
    final CatalogColor? color = entry.catalog;
    return brand == null || color == null || color.brand == brand ? 0 : foreignPenaltyDeltaE;
  }

  /// Подбор ближайших позиций из [candidates] с учётом штрафа чужих брендов; `null` без ограничений.
  NearestColorMatcher<PaletteEntry>? matcher() {
    final List<PaletteEntry>? list = candidates;
    return list == null ? null : NearestColorMatcher<PaletteEntry>(list, rgbOf: (e) => e.rgb, penaltyOf: penaltyOf);
  }

  bool get isFree => candidates == null;

  @override
  List<Object?> get props => <Object?>[candidates, preferredBrand, foreignPenaltyDeltaE];
}
