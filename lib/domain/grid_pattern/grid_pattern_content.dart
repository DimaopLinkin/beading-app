import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_content_cleaner.dart';
import 'package:beading/domain/projects/project_content_cloner.dart';

/// Копирует сетку и палитру в новый проект при дублировании. Прогресс не переносится: у копии работа начинается заново.
class GridPatternContentCloner implements ProjectContentCloner {
  const GridPatternContentCloner({required GridPatternRepository patterns, required IdGenerator ids})
    : _patterns = patterns,
      _ids = ids;

  final GridPatternRepository _patterns;
  final IdGenerator _ids;

  @override
  bool supports(ContentKind kind) => kind == ContentKind.grid;

  @override
  Future<Result<void>> clone({required Project source, required String targetId}) async {
    final Result<GridPattern> found = await _patterns.getByProject(source.id);
    if (found case Err<GridPattern>(:final Failure failure)) {
      // Проект мог остаться без схемы (запись не удалась до конца): копировать нечего.
      return failure is NotFoundFailure ? const Success<void>(null) : Err<void>(failure);
    }
    return _patterns.save(found.valueOrNull!.withIds(id: _ids.next(), projectId: targetId));
  }
}

/// Убирает схему, палитру и прогресс удалённого проекта.
class GridPatternContentCleaner implements ProjectContentCleaner {
  const GridPatternContentCleaner(GridPatternRepository patterns) : _patterns = patterns;

  final GridPatternRepository _patterns;

  @override
  bool supports(ContentKind kind) => kind == ContentKind.grid;

  @override
  Future<Result<void>> remove(Project project) => _patterns.deleteByProject(project.id);
}
