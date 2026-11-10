import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:equatable/equatable.dart';

/// Откуда начинается плетение: угол схемы.
///
/// Вертикальная часть (`top`/`bottom`) говорит, с какого края идёт первый ряд плетения (для станка и кирпичного стежка
/// это верхний или нижний ряд сетки; для мозаики/пейота — направление первого прохода вниз или вверх). Горизонтальная
/// часть (`Left`/`Right`) — с какой стороны идёт первый проход ряда (для мозаики — с какого столбца начинается работа).
enum ReadingStart { topLeft, topRight, bottomLeft, bottomRight }

/// Куда идёт нить в ряду плетения.
enum RowDirection { right, left, down, up }

/// Один ряд плетения: ячейки в том порядке, в котором бусины нанизываются.
final class ReadingRow extends Equatable {
  ReadingRow({required this.index, required this.direction, required List<CellPosition> cells})
    : cells = List<CellPosition>.unmodifiable(cells);

  /// Номер ряда плетения, от нуля.
  final int index;
  final RowDirection direction;
  final List<CellPosition> cells;

  @override
  List<Object?> get props => <Object?>[index, direction, cells];
}

/// Порядок плетения схемы: ряды и направление в каждом. Чистая функция «геометрия и размер → ряды».
///
/// - **Станок** ([RectangularGeometry]): ряды — ряды сетки, направление у всех одно (на станке бисер каждый раз
///   нанизывают с одной стороны).
/// - **Кирпичный стежок** ([BrickGeometry]): ряды — ряды сетки, направление чередуется.
/// - **Мозаика/пейот** ([PeyoteGeometry], `drop: 1`): ряд плетения — столбец сетки, нить идёт вдоль столбца и
///   чередует направление. Порядок внутри первого ряда задаёт геометрия (по высоте центров), поэтому при старте справа и
///   чётном числе столбцов первой нанизывается бусина предпоследнего столбца: он не сдвинут и лежит выше. Первый ряд плетения — два первых столбца, нанизанные вместе зигзагом (так бусины набираются
///   на нить), поэтому рядов плетения на один меньше столбцов. Нечётная мозаика (лишняя бусина в первом столбце)
///   записывается пустой (`0`) ячейкой в конце второго столбца.
/// - Пейот с `drop > 1`: каждый столбец — отдельный ряд, без объединения первых двух (уточнит T35).
///
/// Ряды строятся по запросу ([row]), поэтому схема 4096×4096 не раздувает память.
final class ReadingOrder {
  /// Порядок плетения для схемы из [columns] × [rows] ячеек.
  factory ReadingOrder.of(
    GridGeometry geometry, {
    required int columns,
    required int rows,
    ReadingStart start = ReadingStart.topLeft,
  }) {
    if (columns < 1 || rows < 1) {
      throw ArgumentError('Схема не может быть пустой: $columns × $rows');
    }
    return ReadingOrder._(geometry, columns, rows, start);
  }

  const ReadingOrder._(this.geometry, this.columns, this.rows, this.start);

  final GridGeometry geometry;
  final int columns;
  final int rows;
  final ReadingStart start;

  static const CellMetrics _unit = _UnitMetrics();

  bool get _fromTop => start == ReadingStart.topLeft || start == ReadingStart.topRight;
  bool get _fromLeft => start == ReadingStart.topLeft || start == ReadingStart.bottomLeft;

  /// Сколько рядов плетения.
  int get rowCount => switch (geometry) {
    RectangularGeometry() || BrickGeometry() => rows,
    PeyoteGeometry(:final int drop) => drop == 1 && columns > 1 ? columns - 1 : columns,
  };

  /// Ряд плетения по номеру, от нуля.
  ReadingRow row(int index) {
    RangeError.checkValidIndex(index, this, 'index', rowCount);
    return switch (geometry) {
      RectangularGeometry() => _horizontal(index, alternate: false),
      BrickGeometry() => _horizontal(index, alternate: true),
      PeyoteGeometry(:final int drop) => _vertical(index, combineFirst: drop == 1 && columns > 1),
    };
  }

  /// Все ряды по порядку.
  Iterable<ReadingRow> get allRows sync* {
    for (int i = 0; i < rowCount; i++) {
      yield row(i);
    }
  }

  /// Все ячейки в порядке плетения.
  Iterable<CellPosition> get cells sync* {
    for (final ReadingRow r in allRows) {
      yield* r.cells;
    }
  }

  ReadingRow _horizontal(int index, {required bool alternate}) {
    final int gridRow = _fromTop ? index : rows - 1 - index;
    final bool toRight = _fromLeft == (!alternate || index.isEven);
    return ReadingRow(
      index: index,
      direction: toRight ? RowDirection.right : RowDirection.left,
      cells: <CellPosition>[
        for (int i = 0; i < columns; i++) CellPosition(toRight ? i : columns - 1 - i, gridRow),
      ],
    );
  }

  /// Столбец с номером [position] в порядке начала работы (слева или справа).
  int _columnAt(int position) => _fromLeft ? position : columns - 1 - position;

  ReadingRow _vertical(int index, {required bool combineFirst}) {
    final bool down = _fromTop == index.isEven;
    final RowDirection direction = down ? RowDirection.down : RowDirection.up;
    if (combineFirst && index == 0) {
      final List<CellPosition> cells = <CellPosition>[
        for (final int position in <int>[0, 1])
          for (int r = 0; r < rows; r++) CellPosition(_columnAt(position), r),
      ]..sort((a, b) => _y(a).compareTo(_y(b)));
      return ReadingRow(index: 0, direction: direction, cells: down ? cells : cells.reversed.toList());
    }
    final int column = _columnAt(combineFirst ? index + 1 : index);
    return ReadingRow(
      index: index,
      direction: direction,
      cells: <CellPosition>[for (int i = 0; i < rows; i++) CellPosition(column, down ? i : rows - 1 - i)],
    );
  }

  double _y(CellPosition cell) => geometry.cellCenter(_unit, cell).y;
}

final class _UnitMetrics implements CellMetrics {
  const _UnitMetrics();

  @override
  double get widthMm => 1;

  @override
  double get heightMm => 1;
}
