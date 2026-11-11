import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:equatable/equatable.dart';

/// Из каких цветов можно собирать схему.
///
/// Равенство по значению: два запроса с одним списком допустимых цветов дают один ключ кеша стадий (T58).
///
/// Три режима: свободно ([PaletteConstraint.free]), только каталог выбранного материала и бренда
/// ([PaletteConstraint.catalog]) и заданный список ([PaletteConstraint.list]), например запасы бисера.
final class PaletteConstraint extends Equatable {
  /// Любые цвета: палитра берётся из самой картинки.
  const PaletteConstraint.free() : candidates = null;

  /// Только позиции каталога, подходящие по материалу, брендам, сериям и размеру бисера.
  ///
  /// Пустой [brands], [series], [sizeCodes] или [finishes] не ограничивает; позиция с неизвестной отделкой проходит.
  factory PaletteConstraint.catalog(
    Iterable<CatalogColor> colors, {
    required CatalogMaterial material,
    Set<String> brands = const <String>{},
    Set<String> series = const <String>{},
    Set<String> sizeCodes = const <String>{},
    Set<String> finishes = const <String>{},
  }) => PaletteConstraint.list(<PaletteEntry>[
    for (final CatalogColor color in colors)
      if (color.material == material &&
          (brands.isEmpty || brands.contains(color.brand)) &&
          (series.isEmpty || series.contains(color.series)) &&
          (sizeCodes.isEmpty || (color.sizeCode != null && sizeCodes.contains(color.sizeCode))) &&
          (finishes.isEmpty || color.finish == null || finishes.contains(color.finish)))
        PaletteEntry.fromCatalog(color),
  ]);

  /// Только цвета из списка. Пустой список — ошибка: из ничего схему не собрать.
  PaletteConstraint.list(List<PaletteEntry> entries) : candidates = List<PaletteEntry>.unmodifiable(entries);

  /// Допустимые цвета или `null`, если ограничений нет.
  final List<PaletteEntry>? candidates;

  bool get isFree => candidates == null;

  @override
  List<Object?> get props => <Object?>[candidates];
}
