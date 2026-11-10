import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/use_cases/validate_grid_pattern.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:equatable/equatable.dart';

/// Проект и его новая схема.
final class CreatedGridPattern extends Equatable {
  const CreatedGridPattern({required this.project, required this.pattern});

  final Project project;
  final GridPattern pattern;

  @override
  List<Object?> get props => <Object?>[project, pattern];
}

/// Создаёт проект с `contentKind = grid` и его схему. Если схему не удалось записать, проекта не остаётся.
/// По умолчанию схема пустая: сетка из нулей и пустая палитра.
class CreateGridPattern {
  const CreateGridPattern({
    required CreateProject createProject,
    required ProjectRepository projects,
    required GridPatternRepository patterns,
    required IdGenerator ids,
  }) : _createProject = createProject,
       _projects = projects,
       _patterns = patterns,
       _ids = ids;

  final CreateProject _createProject;
  final ProjectRepository _projects;
  final GridPatternRepository _patterns;
  final IdGenerator _ids;

  Future<Result<CreatedGridPattern>> call({
    required String name,
    required CellMetrics metrics,
    required int width,
    required int height,
    Craft craft = Craft.beading,
    Technique? technique,
    GridGeometry geometry = const GridGeometry.rectangular(),
    Grid? grid,
    PaletteSnapshot? palette,
    String notes = '',
  }) async {
    final Grid cells;
    try {
      cells = grid ?? Grid.empty(width: width, height: height);
    } on ArgumentError catch (error) {
      return Err<CreatedGridPattern>(ValidationFailure('Недопустимый размер сетки: ${error.message}'));
    }
    final PaletteSnapshot colors = palette ?? PaletteSnapshot.empty();
    final Result<void> consistent = validateGridAgainstPalette(cells, colors);
    if (consistent case Err<void>(:final Failure failure)) {
      return Err<CreatedGridPattern>(failure);
    }

    final Result<Project> created = await _createProject(
      name: name,
      craft: craft,
      technique: technique,
      contentKind: ContentKind.grid,
      notes: notes,
    );
    if (created case Err<Project>(:final Failure failure)) {
      return Err<CreatedGridPattern>(failure);
    }
    final Project project = created.valueOrNull!;
    final GridPattern pattern = GridPattern(
      id: _ids.next(),
      projectId: project.id,
      geometry: geometry,
      metrics: metrics,
      grid: cells,
      palette: colors,
    );
    final Result<void> saved = await _patterns.save(pattern);
    if (saved case Err<void>(:final Failure failure)) {
      await _projects.delete(project.id);
      return Err<CreatedGridPattern>(failure);
    }
    return Success<CreatedGridPattern>(CreatedGridPattern(project: project, pattern: pattern));
  }
}
