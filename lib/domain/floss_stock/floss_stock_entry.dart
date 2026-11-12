import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:equatable/equatable.dart';

/// Запас одной нитки мулине: сколько мотков осталось. Доли — «примерно осталось»: `0.5` — половина мотка.
final class FlossStockEntry extends Equatable {
  const FlossStockEntry({required this.ref, required this.skeins, this.updatedAt});

  final CatalogRef ref;

  /// Когда запись менялась в последний раз (UTC): по нему при слиянии побеждает более свежая. `null` у записи, которую
  /// только вводят.
  final DateTime? updatedAt;

  /// Мотков, больше нуля; дробное число — начатый моток.
  final double skeins;

  @override
  List<Object?> get props => <Object?>[ref, skeins, updatedAt];
}
