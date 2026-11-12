import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:equatable/equatable.dart';

/// Запас одного цвета бисера: сколько граммов осталось, примерно.
final class BeadStockEntry extends Equatable {
  const BeadStockEntry({required this.ref, required this.grams, this.updatedAt});

  final CatalogRef ref;

  /// Когда запись менялась в последний раз (UTC): по нему при слиянии побеждает более свежая. `null` у записи, которую
  /// только вводят.
  final DateTime? updatedAt;

  /// Граммов, больше нуля.
  final double grams;

  @override
  List<Object?> get props => <Object?>[ref, grams, updatedAt];
}
