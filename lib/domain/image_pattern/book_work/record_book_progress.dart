import 'package:beading/core/result.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/change_project_status.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';

/// Работа по схеме сдвинулась: проект «идея» становится «в работе» и поднимается в библиотеке.
class RecordBookProgress {
  const RecordBookProgress({
    required ProjectRepository projects,
    required ChangeProjectStatus changeStatus,
    required TouchProject touch,
  }) : _projects = projects,
       _changeStatus = changeStatus,
       _touch = touch;

  final ProjectRepository _projects;
  final ChangeProjectStatus _changeStatus;
  final TouchProject _touch;

  Future<Result<Project>> call(String projectId) async {
    final Result<Project> found = await _projects.get(projectId);
    if (found case Err<Project>()) {
      return found;
    }
    if (found.valueOrNull!.status == ProjectStatus.idea) {
      final Result<Project> changed = await _changeStatus(projectId, ProjectStatus.inProgress);
      if (changed case Err<Project>()) {
        return changed;
      }
    }
    return _touch(projectId);
  }
}
