import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:equatable/equatable.dart';

/// Сколько клеток одного цвета в схеме и сколько из них сделано.
final class ColorCount extends Equatable {
  const ColorCount({required this.color, required this.total, required this.done});

  /// Номер цвета палитры с нуля (значение в сетке минус один).
  final int color;
  final int total;
  final int done;

  int get remaining => total - done;

  @override
  List<Object?> get props => <Object?>[color, total, done];
}

/// Счётчики «сделано / осталось» по цветам и по схеме в целом. Пустые клетки сетки не считаются, отметки на них
/// игнорируются.
abstract final class StitchCounters {
  /// По одному элементу на каждый из [paletteSize] цветов, в порядке палитры.
  static List<ColorCount> byColor(Grid grid, CellProgress progress, {required int paletteSize}) {
    final List<int> total = List<int>.filled(paletteSize, 0);
    final List<int> done = List<int>.filled(paletteSize, 0);
    for (int row = 0; row < grid.height; row++) {
      for (int column = 0; column < grid.width; column++) {
        final int value = grid.at(column, row);
        if (value == 0 || value > paletteSize) {
          continue;
        }
        total[value - 1]++;
        if (progress.isDone(column, row)) {
          done[value - 1]++;
        }
      }
    }
    return <ColorCount>[
      for (int i = 0; i < paletteSize; i++) ColorCount(color: i, total: total[i], done: done[i]),
    ];
  }

  /// Всего клеток с цветом и сколько из них сделано.
  static ({int total, int done}) overall(Grid grid, CellProgress progress) {
    int total = 0;
    int done = 0;
    for (int row = 0; row < grid.height; row++) {
      for (int column = 0; column < grid.width; column++) {
        if (grid.at(column, row) == 0) {
          continue;
        }
        total++;
        if (progress.isDone(column, row)) {
          done++;
        }
      }
    }
    return (total: total, done: done);
  }
}

/// Прогресс одного блока крупной сетки схемы (по умолчанию 10×10, как жирные линии вышивки).
final class BlockCount extends Equatable {
  const BlockCount({required this.blockColumn, required this.blockRow, required this.total, required this.done});

  final int blockColumn;
  final int blockRow;

  /// Клеток с цветом в блоке; у блока без единой клетки `0`.
  final int total;
  final int done;

  bool get isComplete => total > 0 && done >= total;

  /// Доля сделанного, от нуля до единицы; пустой блок считается готовым.
  double get fraction => total == 0 ? 1 : done / total;

  @override
  List<Object?> get props => <Object?>[blockColumn, blockRow, total, done];
}

/// Блоки схемы с прогрессом.
abstract final class StitchBlocks {
  static const int side = 10;

  /// Блоки по рядам слева направо; крайние блоки могут быть неполными. Блоки без клеток с цветом пропускаются.
  static List<BlockCount> compute(Grid grid, CellProgress progress, {int blockSide = side}) {
    final int columns = (grid.width + blockSide - 1) ~/ blockSide;
    final int rows = (grid.height + blockSide - 1) ~/ blockSide;
    final List<BlockCount> result = <BlockCount>[];
    for (int by = 0; by < rows; by++) {
      for (int bx = 0; bx < columns; bx++) {
        int total = 0;
        int done = 0;
        for (int r = by * blockSide; r < (by + 1) * blockSide && r < grid.height; r++) {
          for (int c = bx * blockSide; c < (bx + 1) * blockSide && c < grid.width; c++) {
            if (grid.at(c, r) == 0) {
              continue;
            }
            total++;
            if (progress.isDone(c, r)) {
              done++;
            }
          }
        }
        if (total > 0) {
          result.add(BlockCount(blockColumn: bx, blockRow: by, total: total, done: done));
        }
      }
    }
    return result;
  }
}
