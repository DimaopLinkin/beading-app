import 'package:beading/core/result.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';

/// Заменяет заметки проекта. Пустая строка очищает их.
class UpdateNotes {
  const UpdateNotes(this._repository);

  final ProjectRepository _repository;

  Future<Result<Project>> call(String id, String notes) async {
    final Result<Project> found = await _repository.get(id);
    if (found case Err<Project>()) {
      return found;
    }
    final Project updated = found.valueOrNull!.copyWith(notes: notes);
    final Result<void> saved = await _repository.save(updated);
    return saved.map((_) => updated);
  }
}
