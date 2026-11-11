import 'dart:typed_data';

import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/cell_costs.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Что знает шаг о схеме, кроме самой сетки.
final class PatternStepContext {
  const PatternStepContext({
    required this.geometry,
    required this.cellImportance,
    this.costs,
    this.cellEdges,
    this.cellColors,
  });

  final GridGeometry geometry;

  /// Вес важности каждой ячейки по рядам (без маски везде 1).
  final Float32List cellImportance;

  /// Цена каждого цвета палитры для каждой клетки (столбцы — в порядке `GeneratedPattern.palette`) или `null`,
  /// если конвейер шёл путём T24 без разметки по пикселям.
  final CellCosts? costs;

  /// Сила края в каждой клетке (`cellEdges`) или `null`, если рабочего изображения не было: путь T24.
  final Float32List? cellEdges;

  /// Цвета клеток после ресэмплинга (по рядам, `null` — пустая клетка): по ним шаг видит, какой цвет «хотела» клетка.
  final List<Rgb?>? cellColors;
}

/// Шаг конвейера после привязки к палитре: очистка «конфетти» (T47), слои и им подобное.
///
/// Шаг должен быть передаваемым между изолятами (без замыканий и ресурсов): конвейер запускается в изоляте.
///
/// Чистая функция: получает схему, возвращает новую. Шаги вызываются по порядку и тестируются по отдельности.
abstract interface class PatternStep {
  GeneratedPattern apply(GeneratedPattern pattern, PatternStepContext context);
}
