import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/reading_order.dart';
import 'package:equatable/equatable.dart';

/// Серия одинаковых бусин подряд: «3 × A».
final class WordRun extends Equatable {
  const WordRun(this.colorIndex, this.count);

  /// Значение сетки (индекс палитры с 1).
  final int colorIndex;
  final int count;

  @override
  List<Object?> get props => <Object?>[colorIndex, count];

  @override
  String toString() => '$count × $colorIndex';
}

/// Word chart одного ряда плетения.
final class WordChartRow extends Equatable {
  WordChartRow({required this.index, required this.direction, required List<WordRun> runs})
    : runs = List<WordRun>.unmodifiable(runs);

  /// Номер ряда плетения, от нуля.
  final int index;
  final RowDirection direction;
  final List<WordRun> runs;

  /// Бусин в ряду (без пустых ячеек).
  int get beadCount => runs.fold(0, (sum, run) => sum + run.count);

  @override
  List<Object?> get props => <Object?>[index, direction, runs];
}

/// Word chart: ряд за рядом серии одинаковых бусин в порядке плетения.
///
/// Серии склеиваются только внутри ряда. Пустая ячейка (`0`) не бусина: в word chart её нет, но она рвёт серию
/// (бусины одного цвета по обе стороны пропуска — две серии).
abstract final class WordChart {
  /// Серии одного ряда плетения.
  static List<WordRun> forRow(Grid grid, ReadingRow row) {
    final List<WordRun> runs = <WordRun>[];
    int color = 0;
    int count = 0;
    void flush() {
      if (count > 0) runs.add(WordRun(color, count));
      count = 0;
    }

    for (final cell in row.cells) {
      final int value = grid.at(cell.column, cell.row);
      if (value == 0) {
        flush();
        color = 0;
      } else if (value == color) {
        count++;
      } else {
        flush();
        color = value;
        count = 1;
      }
    }
    flush();
    return runs;
  }

  /// Word chart всей схемы. Размер [grid] должен совпадать с размером, для которого построен [order].
  static List<WordChartRow> build(Grid grid, ReadingOrder order) {
    if (grid.width != order.columns || grid.height != order.rows) {
      throw ArgumentError(
        'Порядок плетения для ${order.columns} × ${order.rows}, а сетка ${grid.width} × ${grid.height}',
      );
    }
    return <WordChartRow>[
      for (final ReadingRow row in order.allRows)
        WordChartRow(index: row.index, direction: row.direction, runs: forRow(grid, row)),
    ];
  }
}
