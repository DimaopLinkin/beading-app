import 'package:beading/core/result.dart';
import 'package:beading/domain/projects/project_repository.dart';

/// Мягко удаляет проект: из библиотеки он исчезает, надгробие доедет до второго устройства.
class DeleteProject {
  const DeleteProject(this._repository);

  final ProjectRepository _repository;

  Future<Result<void>> call(String id) => _repository.delete(id);
}
