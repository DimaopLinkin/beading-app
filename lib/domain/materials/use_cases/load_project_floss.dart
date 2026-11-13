import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/domain/grid_pattern/cell_progress_store.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_layers_codec.dart';

/// Считает мулине для схемы вышивки проекта: нитки по цветам, список покупок и канву.
///
/// Нужна схема на канве ([Fabric]); для бисерной схемы возвращает [ValidationFailure].
final class LoadProjectFloss {
  const LoadProjectFloss(this._patterns, {CellProgressStore? progress}) : _progress = progress;

  final GridPatternRepository _patterns;
  final CellProgressStore? _progress;

  /// [NotFoundFailure], если у проекта нет схемы.
  ///
  /// С [remainingOnly] крестики уже вышитых клеток не считаются: это «сколько ниток нужно на оставшуюся работу».
  /// Неполные крестики, бэкстич и узелки считаются целиком: прогресс по ним не хранится. Нужно хранилище прогресса,
  /// иначе [ValidationFailure].
  Future<Result<FlossEstimate>> call(
    String projectId, {
    double reserve = FlossEstimator.defaultReserve,
    bool remainingOnly = false,
  }) async {
    if (remainingOnly && _progress == null) {
      return const Err<FlossEstimate>(ValidationFailure('Для остатка работы нужен прогресс по клеткам'));
    }
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
        Grid grid = pattern.grid;
        if (remainingOnly) {
          final Result<CellProgress> done = await _progress!.load(pattern.id);
          if (done case Err<CellProgress>(:final Failure failure)) return Err<FlossEstimate>(failure);
          grid = _withoutDone(grid, done.valueOrNull!);
        }
        try {
          return Success<FlossEstimate>(
            FlossEstimator(fabric: metrics, layers: layers, reserve: reserve).estimate(grid, pattern.palette),
          );
        } on ArgumentError catch (e) {
          return Err<FlossEstimate>(ValidationFailure('${e.message}'));
        }
    }
  }

  static Grid _withoutDone(Grid grid, CellProgress done) {
    if (done.isEmpty) return grid;
    final List<int> cells = grid.cells.toList();
    for (final cell in done.cells(height: grid.height)) {
      if (cell.column < grid.width) cells[cell.row * grid.width + cell.column] = 0;
    }
    return Grid.fromCells(width: grid.width, height: grid.height, cells: cells);
  }
}
