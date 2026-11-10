import 'package:beading/core/result.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_content_cleaner.dart';
import 'package:beading/domain/projects/project_repository.dart';

/// Мягко удаляет проект: из библиотеки он исчезает, надгробие доедет до второго устройства.
/// Следом [ProjectContentCleaner]-ы убирают файлы и строки содержимого.
class DeleteProject {
  const DeleteProject(this._repository, {List<ProjectContentCleaner> cleaners = const <ProjectContentCleaner>[]})
    : _cleaners = cleaners;

  final ProjectRepository _repository;
  final List<ProjectContentCleaner> _cleaners;

  /// Сбой уборки не отменяет удаление: проект уже исчез из библиотеки, повторить это пользователь не сможет.
  Future<Result<void>> call(String id) async {
    final Result<Project> found = await _repository.get(id);
    if (found case Err<Project>(:final failure)) {
      return Err<void>(failure);
    }
    final Project project = found.valueOrNull!;
    final Result<void> deleted = await _repository.delete(id);
    if (deleted case Err<void>()) {
      return deleted;
    }
    for (final ProjectContentCleaner cleaner in _cleaners.where((c) => c.supports(project.contentKind))) {
      try {
        await cleaner.remove(project);
      } on Object {
        // Уборка по возможности: исключение одной не должно мешать остальным.
        continue;
      }
    }
    return const Success<void>(null);
  }
}
