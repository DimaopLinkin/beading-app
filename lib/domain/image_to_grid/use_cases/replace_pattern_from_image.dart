import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/domain/grid_pattern/cell_progress_store.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/grid_pattern/grid_progress_store.dart';
import 'package:beading/domain/grid_pattern/use_cases/save_grid_pattern.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/palette_from_generated.dart';
import 'package:beading/domain/image_to_grid/use_cases/create_pattern_from_image.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/rename_project.dart';

/// Заменяет схему уже созданного проекта результатом мастера (T79): сетка, палитра, размер ячейки и слои новые,
/// проект, его обложка и заметки остаются. Прогресс прежней сетки к новой не подходит, поэтому перед заменой
/// вызывающий проверяет [hasProgress] и при отметках предлагает сохранить копией.
class ReplacePatternFromImage {
  const ReplacePatternFromImage({
    required GridPatternRepository patterns,
    required GridProgressStore rows,
    required CellProgressStore cells,
    required ProjectRepository projects,
  }) : _patterns = patterns,
       _rows = rows,
       _cells = cells,
       _projects = projects;

  final GridPatternRepository _patterns;
  final GridProgressStore _rows;
  final CellProgressStore _cells;
  final ProjectRepository _projects;

  /// Есть ли у схемы проекта отметки: выполненные ряды, «остановилась здесь» или закрашенные клетки.
  Future<bool> hasProgress(String projectId) async {
    final GridPattern? pattern = (await _patterns.getByProject(projectId)).valueOrNull;
    if (pattern == null) return false;
    final GridProgress? rows = (await _rows.load(pattern.id)).valueOrNull;
    if (rows != null && (rows.completedRows.isNotEmpty || rows.currentRow != null)) return true;
    final CellProgress? cells = (await _cells.load(pattern.id)).valueOrNull;
    return cells != null && !cells.isEmpty;
  }

  Future<Result<Project>> call({
    required String projectId,
    required String name,
    required CellMetrics metrics,
    required GeneratedPattern generated,
  }) async {
    final Result<Project> found = await _projects.get(projectId);
    if (found case Err<Project>(:final Failure failure)) return Err<Project>(failure);
    final Project project = found.valueOrNull!;
    final Result<GridPattern> existing = await _patterns.getByProject(projectId);
    if (existing case Err<GridPattern>(:final Failure failure)) return Err<Project>(failure);
    final Result<PaletteSnapshot> palette = paletteFromGenerated(generated);
    if (palette case Err<PaletteSnapshot>(:final Failure failure)) return Err<Project>(failure);
    final Result<Project> renamed = await RenameProject(_projects)(projectId, name);
    if (renamed case Err<Project>(:final Failure failure)) return Err<Project>(failure);
    final GridPattern old = existing.valueOrNull!;
    final GridLayersBlob? layers = CreatePatternFromImage.layersForGenerated(generated, project.technique, metrics);
    final Result<void> saved = await SaveGridPattern(_patterns)(
      old.copyWith(
        metrics: metrics,
        grid: generated.grid,
        palette: palette.valueOrNull,
        layers: layers,
        clearLayers: layers == null,
      ),
    );
    if (saved case Err<void>(:final Failure failure)) return Err<Project>(failure);
    return Success<Project>(renamed.valueOrNull!);
  }
}
