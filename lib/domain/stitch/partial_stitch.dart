import 'package:beading/domain/grid/cell_position.dart';
import 'package:equatable/equatable.dart';

/// Вид неполного крестика.
enum PartialKind {
  /// Полукрестик: одна диагональ клетки ([StitchOrientation.slash] или [StitchOrientation.backslash]).
  half,

  /// Четверть: стежок от угла клетки до её центра (угол — в [StitchOrientation]).
  quarter,

  /// ¾: диагональ клетки, не проходящая через угол [StitchOrientation], плюс четверть от этого угла до центра.
  threeQuarter,

  /// Петит: маленький крестик в четверти клетки у угла (равномерка и лён).
  petit,

  /// Гобеленовый стежок: наклонный стежок поверх клетки, диагональ задаёт [StitchOrientation].
  tent,
}

/// Куда направлен неполный крестик: угол клетки или диагональ (`/` — снизу слева вверх направо, `\` — наоборот).
enum StitchOrientation { topLeft, topRight, bottomLeft, bottomRight, slash, backslash }

/// Неполный крестик в клетке `(column, row)`. Цвет — значение сетки, то есть `palette[color - 1]`.
///
/// В клетке может быть несколько неполных крестиков, но не два одного вида с одной ориентацией: это ключ [key].
final class PartialStitch extends Equatable implements Comparable<PartialStitch> {
  PartialStitch({
    required this.column,
    required this.row,
    required this.kind,
    required this.orientation,
    required this.color,
  }) {
    if (column < 0 || row < 0) throw ArgumentError('клетка $column, $row вне схемы');
    if (color < 1 || color > maxColor) throw ArgumentError.value(color, 'color', 'от 1 до $maxColor');
    if (!orientationFits(kind, orientation)) {
      throw ArgumentError('ориентация $orientation не подходит к виду $kind');
    }
  }

  static const int maxColor = 0xFFFF;

  /// Диагонали подходят полукрестику и гобеленовому стежку, углы — остальным.
  static bool orientationFits(PartialKind kind, StitchOrientation orientation) {
    final bool diagonal = orientation == StitchOrientation.slash || orientation == StitchOrientation.backslash;
    return (kind == PartialKind.half || kind == PartialKind.tent) == diagonal;
  }

  final int column;
  final int row;
  final PartialKind kind;
  final StitchOrientation orientation;
  final int color;

  CellPosition get cell => CellPosition(column, row);

  /// Что считается одним и тем же стежком: клетка, вид и ориентация (цвет — нет).
  (int, int, PartialKind, StitchOrientation) get key => (column, row, kind, orientation);

  PartialStitch copyWith({int? column, int? row, int? color, StitchOrientation? orientation}) => PartialStitch(
    column: column ?? this.column,
    row: row ?? this.row,
    kind: kind,
    orientation: orientation ?? this.orientation,
    color: color ?? this.color,
  );

  @override
  int compareTo(PartialStitch other) {
    if (row != other.row) return row.compareTo(other.row);
    if (column != other.column) return column.compareTo(other.column);
    if (kind != other.kind) return kind.index.compareTo(other.kind.index);
    return orientation.index.compareTo(other.orientation.index);
  }

  @override
  List<Object?> get props => <Object?>[column, row, kind, orientation, color];
}
