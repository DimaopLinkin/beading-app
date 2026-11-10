import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:equatable/equatable.dart';

/// Прямоугольная область ячеек: выделение. Границы включительно, от нуля.
final class CellRect extends Equatable {
  const CellRect({required this.left, required this.top, required this.width, required this.height})
    : assert(width >= 1 && height >= 1, 'область не может быть пустой');

  /// Прямоугольник по двум противоположным углам в любом порядке.
  factory CellRect.fromCorners(CellPosition a, CellPosition b) {
    final int left = a.column < b.column ? a.column : b.column;
    final int top = a.row < b.row ? a.row : b.row;
    return CellRect(
      left: left,
      top: top,
      width: (a.column - b.column).abs() + 1,
      height: (a.row - b.row).abs() + 1,
    );
  }

  /// Вся сетка.
  factory CellRect.all(Grid grid) => CellRect(left: 0, top: 0, width: grid.width, height: grid.height);

  final int left;
  final int top;
  final int width;
  final int height;

  int get right => left + width - 1;

  int get bottom => top + height - 1;

  bool contains(CellPosition cell) =>
      cell.column >= left && cell.column <= right && cell.row >= top && cell.row <= bottom;

  /// Пересечение с сеткой или `null`, если область целиком за её пределами.
  CellRect? clipTo(Grid grid) {
    final int l = left < 0 ? 0 : left;
    final int t = top < 0 ? 0 : top;
    final int r = right > grid.width - 1 ? grid.width - 1 : right;
    final int b = bottom > grid.height - 1 ? grid.height - 1 : bottom;
    if (l > r || t > b) return null;
    return CellRect(left: l, top: t, width: r - l + 1, height: b - t + 1);
  }

  @override
  List<Object?> get props => <Object?>[left, top, width, height];

  @override
  String toString() => 'CellRect($left, $top, $width×$height)';
}
