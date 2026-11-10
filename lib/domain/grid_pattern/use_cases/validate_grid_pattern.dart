import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';

/// Проверяет, что в сетке нет значений, для которых нет цвета палитры.
Result<void> validateGridAgainstPalette(Grid grid, PaletteSnapshot palette) {
  final int largest = grid.cells.fold<int>(0, (a, b) => a > b ? a : b);
  if (largest > palette.length) {
    return Err<void>(ValidationFailure('В сетке есть цвет $largest, а в палитре ${palette.length}'));
  }
  return const Success<void>(null);
}
