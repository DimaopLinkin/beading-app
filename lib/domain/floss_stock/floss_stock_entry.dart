import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:equatable/equatable.dart';

/// Запас одной нитки мулине: сколько мотков осталось. Доли — «примерно осталось»: `0.5` — половина мотка.
final class FlossStockEntry extends Equatable {
  const FlossStockEntry({required this.ref, required this.skeins});

  final CatalogRef ref;

  /// Мотков, больше нуля; дробное число — начатый моток.
  final double skeins;

  @override
  List<Object?> get props => <Object?>[ref, skeins];
}
