import 'package:equatable/equatable.dart';

/// Позиция ячейки в сетке: столбец и ряд, от нуля.
final class CellPosition extends Equatable {
  const CellPosition(this.column, this.row);

  final int column;
  final int row;

  @override
  List<Object?> get props => <Object?>[column, row];

  @override
  String toString() => '($column, $row)';
}
