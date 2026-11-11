import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_layers_codec.dart';

/// Считает мулине для схемы вышивки проекта: нитки по цветам, список покупок и канву.
///
/// Нужна схема на канве ([Fabric]); для бисерной схемы возвращает [ValidationFailure].
final class LoadProjectFloss {
  const LoadProjectFloss(this._patterns);

  final GridPatternRepository _patterns;

  /// [NotFoundFailure], если у проекта нет схемы.
  Future<Result<FlossEstimate>> call(String projectId, {double reserve = FlossEstimator.defaultReserve}) async {
    final Result<GridPattern> loaded = await _patterns.getByProject(projectId);
    switch (loaded) {
      case Err<GridPattern>(:final Failure failure):
        return Err<FlossEstimate>(failure);
      case Success<GridPattern>(value: final GridPattern pattern):
        final Object metrics = pattern.metrics;
        if (metrics is! Fabric) {
          return const Err<FlossEstimate>(ValidationFailure('Расход мулине считается только для схемы на канве'));
        }
        final StitchLayers layers;
        if (pattern.layers == null) {
          layers = StitchLayers.empty(columns: pattern.grid.width, rows: pattern.grid.height);
        } else {
          final Result<StitchLayers> decoded = StitchLayersCodec.fromBlob(pattern.layers!);
          if (decoded case Err<StitchLayers>(:final Failure failure)) return Err<FlossEstimate>(failure);
          layers = decoded.valueOrNull!;
        }
        try {
          return Success<FlossEstimate>(
            FlossEstimator(fabric: metrics, layers: layers, reserve: reserve).estimate(pattern.grid, pattern.palette),
          );
        } on ArgumentError catch (e) {
          return Err<FlossEstimate>(ValidationFailure('${e.message}'));
        }
    }
  }
}
