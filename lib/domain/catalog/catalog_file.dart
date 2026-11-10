import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:equatable/equatable.dart';

/// Один файл каталога из `assets/catalog`: бренд, серия, размер и позиции.
final class CatalogFile extends Equatable {
  const CatalogFile({
    required this.id,
    required this.version,
    required this.material,
    required this.brand,
    required this.series,
    required this.sizeCode,
    required this.colors,
  });

  /// Имя файла без расширения; ключ наполнения.
  final String id;

  /// Растёт при каждом изменении содержимого: по нему база понимает, что файл надо загрузить заново.
  final int version;

  final CatalogMaterial material;
  final String brand;
  final String series;
  final String? sizeCode;
  final List<CatalogColor> colors;

  @override
  List<Object?> get props => <Object?>[id, version, material, brand, series, sizeCode, colors];
}
