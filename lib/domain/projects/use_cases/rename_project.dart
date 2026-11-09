import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/project_name.dart';

class RenameProject {
  const RenameProject(this._repository);

  final ProjectRepository _repository;

  Future<Result<Project>> call(String id, String name) async {
    final Result<String> validName = validateProjectName(name);
    if (validName case Err<String>(:final Failure failure)) {
      return Err<Project>(failure);
    }
    final Result<Project> found = await _repository.get(id);
    if (found case Err<Project>()) {
      return found;
    }
    final Project renamed = found.valueOrNull!.copyWith(name: validName.valueOrNull);
    final Result<void> saved = await _repository.save(renamed);
    return saved.map((_) => renamed);
  }
}
