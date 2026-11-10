import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:equatable/equatable.dart';

/// Позиция каталога: бисер или нитка конкретного бренда.
///
/// RGB приблизительный: это цвет для экрана, а не колориметрическая мера (см. `assets/catalog/README.md`).
final class CatalogColor extends Equatable {
  const CatalogColor({
    required this.material,
    required this.brand,
    required this.series,
    required this.code,
    required this.name,
    required this.rgb,
    this.finish,
    this.sizeCode,
  });

  final CatalogMaterial material;

  /// Бренд, например `Miyuki`.
  final String brand;

  /// Серия внутри бренда, например `Delica`.
  final String series;

  /// Артикул как на упаковке, например `DB0010`.
  final String code;

  final String name;
  final Rgb rgb;

  /// Отделка (`opaque`, `transparent`, `metallic`, …) или `null`, если неизвестна.
  final String? finish;

  /// Размер бисера (`11/0`) или `null` для ниток.
  final String? sizeCode;

  /// Стабильный идентификатор позиции: одинаков при каждом наполнении и на всех устройствах.
  String get id => '${material.wire}|$brand|$series|${sizeCode ?? ''}|$code';

  /// Ссылка для хранения в палитре схемы. Серия в ссылку не входит: артикул бренда уникален внутри бренда.
  CatalogRef get ref => CatalogRef(brand: brand, code: code);

  @override
  List<Object?> get props => <Object?>[material, brand, series, code, name, rgb, finish, sizeCode];
}
