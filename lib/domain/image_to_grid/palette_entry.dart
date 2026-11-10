import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:equatable/equatable.dart';

/// Цвет результата: позиция каталога или, при свободной палитре, просто цвет.
final class PaletteEntry extends Equatable {
  const PaletteEntry({required this.rgb, this.catalog});

  /// Цвет позиции каталога: показывается её собственный RGB.
  factory PaletteEntry.fromCatalog(CatalogColor color) => PaletteEntry(rgb: color.rgb, catalog: color);

  final Rgb rgb;

  /// Позиция каталога или `null` для цвета вне каталога.
  final CatalogColor? catalog;

  @override
  List<Object?> get props => <Object?>[rgb, catalog];
}
