import 'package:equatable/equatable.dart';

/// Позиция каталога: бренд и артикул (например, DMC 310, Miyuki Delica DB0010).
final class CatalogRef extends Equatable {
  const CatalogRef({required this.brand, required this.code});

  final String brand;
  final String code;

  @override
  List<Object?> get props => <Object?>[brand, code];

  @override
  String toString() => '$brand $code';
}
