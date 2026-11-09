import 'package:beading/core/clock.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';

/// Отмечает, что над проектом только что работали: он поднимается в начало библиотеки.
class TouchProject {
  const TouchProject({required ProjectRepository repository, required Clock clock})
    : _repository = repository,
      _clock = clock;

  final ProjectRepository _repository;
  final Clock _clock;

  Future<Result<Project>> call(String id) async {
    final Result<Project> found = await _repository.get(id);
    if (found case Err<Project>()) {
      return found;
    }
    final Project touched = found.valueOrNull!.copyWith(lastWorkedAt: _clock.now().toUtc());
    final Result<void> saved = await _repository.save(touched);
    return saved.map((_) => touched);
  }
}
