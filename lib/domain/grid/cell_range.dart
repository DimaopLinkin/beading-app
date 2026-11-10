import 'package:equatable/equatable.dart';

/// Прямоугольный диапазон ячеек: границы включительно. Пустой, если первая позиция больше последней.
final class CellRange extends Equatable {
  const CellRange({
    required this.firstColumn,
    required this.lastColumn,
    required this.firstRow,
    required this.lastRow,
  });

  /// Диапазон без ячеек.
  const CellRange.empty() : this(firstColumn: 0, lastColumn: -1, firstRow: 0, lastRow: -1);

  final int firstColumn;
  final int lastColumn;
  final int firstRow;
  final int lastRow;

  bool get isEmpty => firstColumn > lastColumn || firstRow > lastRow;

  bool contains(int column, int row) =>
      column >= firstColumn && column <= lastColumn && row >= firstRow && row <= lastRow;

  @override
  List<Object?> get props => <Object?>[firstColumn, lastColumn, firstRow, lastRow];
}
