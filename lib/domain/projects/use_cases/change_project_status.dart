import 'package:beading/core/result.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';

/// Меняет статус. Переход в «готово» из другого статуса публикует [ProjectCompleted].
class ChangeProjectStatus {
  const ChangeProjectStatus({required ProjectRepository repository, required AppEvents events})
    : _repository = repository,
      _events = events;

  final ProjectRepository _repository;
  final AppEvents _events;

  Future<Result<Project>> call(String id, ProjectStatus status) async {
    final Result<Project> found = await _repository.get(id);
    if (found case Err<Project>()) {
      return found;
    }
    final Project current = found.valueOrNull!;
    if (current.status == status) {
      return found;
    }
    final Project changed = current.copyWith(status: status);
    final Result<void> saved = await _repository.save(changed);
    if (saved case Err<void>(:final failure)) {
      return Err<Project>(failure);
    }
    if (status == ProjectStatus.done) {
      _events.publish(ProjectCompleted(id));
    }
    return Success<Project>(changed);
  }
}
