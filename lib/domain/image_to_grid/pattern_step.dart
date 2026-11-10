import 'dart:typed_data';

import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';

/// Что знает шаг о схеме, кроме самой сетки.
final class PatternStepContext {
  const PatternStepContext({required this.geometry, required this.cellImportance});

  final GridGeometry geometry;

  /// Вес важности каждой ячейки по рядам (без маски везде 1).
  final Float32List cellImportance;
}

/// Шаг конвейера после привязки к палитре: очистка «конфетти» (T47), слои и им подобное.
///
/// Шаг должен быть передаваемым между изолятами (без замыканий и ресурсов): конвейер запускается в изоляте.
///
/// Чистая функция: получает схему, возвращает новую. Шаги вызываются по порядку и тестируются по отдельности.
abstract interface class PatternStep {
  GeneratedPattern apply(GeneratedPattern pattern, PatternStepContext context);
}
