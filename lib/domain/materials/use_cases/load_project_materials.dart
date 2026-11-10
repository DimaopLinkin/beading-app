import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/materials/bead_estimate.dart';

/// Считает бисер для сеточной схемы проекта: штуки и граммы по цветам с запасом.
///
/// Вес известен только у бусины из справочника ([BeadSize]); для произвольного размера ячейки возвращает
/// [ValidationFailure]. Расчёт ниток для вышивки добавит T44 своим `MaterialEstimator`.
final class LoadProjectMaterials {
  const LoadProjectMaterials(this._patterns);

  final GridPatternRepository _patterns;

  /// [NotFoundFailure], если у проекта нет схемы.
  Future<Result<BeadEstimate>> call(String projectId, {double reserve = BeadEstimator.defaultReserve}) async {
    final Result<GridPattern> loaded = await _patterns.getByProject(projectId);
    switch (loaded) {
      case Err<GridPattern>(:final Failure failure):
        return Err<BeadEstimate>(failure);
      case Success<GridPattern>(value: final GridPattern pattern):
        final CellMetrics metrics = pattern.metrics;
        if (metrics is! BeadSize) {
          return const Err<BeadEstimate>(ValidationFailure('Вес известен только для бусины из справочника'));
        }
        try {
          return Success<BeadEstimate>(
            BeadEstimator(beadSize: metrics, reserve: reserve).estimate(pattern.grid, pattern.palette),
          );
        } on ArgumentError catch (e) {
          return Err<BeadEstimate>(ValidationFailure('${e.message}'));
        }
    }
  }
}
