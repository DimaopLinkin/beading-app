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
