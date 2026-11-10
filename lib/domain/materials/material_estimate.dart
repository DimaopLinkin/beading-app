import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';

/// Строка расхода: один цвет схемы.
abstract interface class MaterialLine {
  /// Значение сетки (индекс палитры с 1).
  int get colorIndex;

  PatternColor get color;
}

/// Расход материалов на схему. Конкретный вид (бусины, мулине) знает своя реализация.
abstract interface class MaterialEstimate {
  /// Строки по цветам в порядке палитры; цвета, которых нет в схеме, не включаются.
  List<MaterialLine> get lines;

  /// Запас сверх расчёта, доля (`0.1` — 10%).
  double get reserve;
}

/// Считает расход материалов по схеме: `BeadEstimator` для бисера, `FlossEstimator` (T44) для вышивки.
abstract interface class MaterialEstimator {
  MaterialEstimate estimate(Grid grid, PaletteSnapshot palette);
}
