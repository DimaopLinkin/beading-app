import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/mm.dart';

/// Как ячейки схемы лежат на плоскости: центры, попадание точкой, соседи и габариты.
///
/// Размер ячейки берётся только из [CellMetrics]. Метрики заданы для положения «отверстие вдоль ряда»; геометрия,
/// где бусина лежит иначе (кирпичный стежок), сама меняет ширину и высоту местами.
///
/// Все методы чистые. Сетка из `columns` × `rows` ячеек, позиции от нуля, начало координат — левый верхний угол.
sealed class GridGeometry {
  const GridGeometry();

  /// Ровные ряды и столбцы: станок, квадратный стежок, вышивка.
  const factory GridGeometry.rectangular() = RectangularGeometry;

  /// Мозаика/пейот: столбцы сдвинуты на ½ ячейки по вертикали группами по [drop] столбцов (1 — обычный пейот,
  /// 2 — 2-drop и т. д.).
  const factory GridGeometry.peyote({int drop}) = PeyoteGeometry;

  /// Кирпичный стежок: нечётные ряды сдвинуты на ½ ячейки по горизонтали. Ряды разной длины выражаются пустыми
  /// ячейками (`0`) в прямоугольной [Grid].
  const factory GridGeometry.brick() = BrickGeometry;

  /// Центр ячейки, мм.
  MmPoint cellCenter(CellMetrics metrics, CellPosition cell);

  /// Размер описывающего прямоугольника схемы, мм.
  MmSize extent(CellMetrics metrics, {required int columns, required int rows});

  /// Ячейка под точкой или `null`, если точка вне ячеек (за схемой или в «зубце» сдвинутого края).
  CellPosition? cellAt(CellMetrics metrics, {required int columns, required int rows, required MmPoint point});

  /// Ячейки, граничащие со стороной данной ячейки (для заливки), по порядку «ряд, затем столбец».
  List<CellPosition> neighbors({required int columns, required int rows, required CellPosition cell});
}

/// Ровные ряды и столбцы.
final class RectangularGeometry extends GridGeometry {
  const RectangularGeometry();

  @override
  MmPoint cellCenter(CellMetrics metrics, CellPosition cell) =>
      MmPoint((cell.column + 0.5) * metrics.widthMm, (cell.row + 0.5) * metrics.heightMm);

  @override
  MmSize extent(CellMetrics metrics, {required int columns, required int rows}) =>
      MmSize(columns * metrics.widthMm, rows * metrics.heightMm);

  @override
  CellPosition? cellAt(CellMetrics metrics, {required int columns, required int rows, required MmPoint point}) {
    if (!point.x.isFinite || !point.y.isFinite || point.x < 0 || point.y < 0) return null;
    final int column = (point.x / metrics.widthMm).floor();
    final int row = (point.y / metrics.heightMm).floor();
    if (column >= columns || row >= rows) return null;
    return CellPosition(column, row);
  }

  @override
  List<CellPosition> neighbors({required int columns, required int rows, required CellPosition cell}) {
    final int column = cell.column;
    final int row = cell.row;
    return <CellPosition>[
      if (row > 0) CellPosition(column, row - 1),
      if (column > 0) CellPosition(column - 1, row),
      if (column < columns - 1) CellPosition(column + 1, row),
      if (row < rows - 1) CellPosition(column, row + 1),
    ];
  }
}

/// Столбцы со сдвигом на ½ ячейки по вертикали, группами по [drop].
final class PeyoteGeometry extends GridGeometry {
  const PeyoteGeometry({this.drop = 1}) : assert(drop >= 1, 'drop должен быть не меньше 1');

  /// Сколько соседних столбцов сдвинуты вместе.
  final int drop;

  /// Сдвинут ли столбец вниз на половину ячейки.
  bool _isShifted(int column) => (column ~/ drop).isOdd;

  @override
  MmPoint cellCenter(CellMetrics metrics, CellPosition cell) => MmPoint(
    (cell.column + 0.5) * metrics.widthMm,
    (cell.row + 0.5 + (_isShifted(cell.column) ? 0.5 : 0)) * metrics.heightMm,
  );

  @override
  MmSize extent(CellMetrics metrics, {required int columns, required int rows}) =>
      MmSize(columns * metrics.widthMm, (rows + (columns > drop ? 0.5 : 0)) * metrics.heightMm);

  @override
  CellPosition? cellAt(CellMetrics metrics, {required int columns, required int rows, required MmPoint point}) {
    if (!point.x.isFinite || !point.y.isFinite || point.x < 0 || point.y < 0) return null;
    final int column = (point.x / metrics.widthMm).floor();
    if (column >= columns) return null;
    final double top = _isShifted(column) ? metrics.heightMm / 2 : 0;
    final double inColumn = point.y - top;
    if (inColumn < 0) return null;
    final int row = (inColumn / metrics.heightMm).floor();
    if (row >= rows) return null;
    return CellPosition(column, row);
  }

  @override
  List<CellPosition> neighbors({required int columns, required int rows, required CellPosition cell}) {
    final int column = cell.column;
    final int row = cell.row;
    final List<CellPosition> result = <CellPosition>[];
    if (row > 0) result.add(CellPosition(column, row - 1));
    for (final int side in <int>[column - 1, column + 1]) {
      if (side < 0 || side >= columns) continue;
      // Разница сдвигов в половинах ячейки: 0 — та же высота, ±1 — соседний столбец сдвинут на ½.
      final int shiftDelta = (_isShifted(column) ? 1 : 0) - (_isShifted(side) ? 1 : 0);
      final List<int> rowsInSide = switch (shiftDelta) {
        0 => <int>[row],
        1 => <int>[row, row + 1],
        _ => <int>[row - 1, row],
      };
      for (final int sideRow in rowsInSide) {
        if (sideRow >= 0 && sideRow < rows) result.add(CellPosition(side, sideRow));
      }
    }
    if (row < rows - 1) result.add(CellPosition(column, row + 1));
    result.sort(_byRowThenColumn);
    return result;
  }
}

/// Ряды со сдвигом на ½ ячейки по горизонтали.
///
/// Это пейот с `drop: 1`, повёрнутый на 90°: координаты, позиции и габариты транспонируются. Ширина и высота ячейки
/// при этом сами меняются местами — отверстие бусины идёт поперёк ряда.
final class BrickGeometry extends GridGeometry {
  const BrickGeometry();

  static const PeyoteGeometry _transposed = PeyoteGeometry();

  @override
  MmPoint cellCenter(CellMetrics metrics, CellPosition cell) {
    final MmPoint center = _transposed.cellCenter(metrics, _swap(cell));
    return MmPoint(center.y, center.x);
  }

  @override
  MmSize extent(CellMetrics metrics, {required int columns, required int rows}) {
    final MmSize size = _transposed.extent(metrics, columns: rows, rows: columns);
    return MmSize(size.height, size.width);
  }

  @override
  CellPosition? cellAt(CellMetrics metrics, {required int columns, required int rows, required MmPoint point}) {
    final CellPosition? cell = _transposed.cellAt(
      metrics,
      columns: rows,
      rows: columns,
      point: MmPoint(point.y, point.x),
    );
    return cell == null ? null : _swap(cell);
  }

  @override
  List<CellPosition> neighbors({required int columns, required int rows, required CellPosition cell}) {
    final List<CellPosition> result =
        _transposed.neighbors(columns: rows, rows: columns, cell: _swap(cell)).map(_swap).toList()
          ..sort(_byRowThenColumn);
    return result;
  }

  static CellPosition _swap(CellPosition cell) => CellPosition(cell.row, cell.column);
}

int _byRowThenColumn(CellPosition a, CellPosition b) => a.row != b.row ? a.row - b.row : a.column - b.column;
