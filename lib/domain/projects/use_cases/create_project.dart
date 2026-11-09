import 'package:beading/core/clock.dart';
import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/project_name.dart';

/// Создаёт проект со статусом «идея». Техника по умолчанию — первая у выбранного ремесла.
class CreateProject {
  const CreateProject({required ProjectRepository repository, required IdGenerator ids, required Clock clock})
    : _repository = repository,
      _ids = ids,
      _clock = clock;

  final ProjectRepository _repository;
  final IdGenerator _ids;
  final Clock _clock;

  Future<Result<Project>> call({
    required String name,
    Craft craft = Craft.beading,
    Technique? technique,
    ContentKind contentKind = ContentKind.image,
    String notes = '',
  }) async {
    final Result<String> validName = validateProjectName(name);
    if (validName case Err<String>(:final Failure failure)) {
      return Err<Project>(failure);
    }
    final Technique chosen = technique ?? Technique.defaultFor(craft);
    if (chosen.craft != craft) {
      return Err<Project>(ValidationFailure('Техника ${chosen.name} не подходит для ремесла ${craft.name}'));
    }
    final Project project = Project(
      id: _ids.next(),
      name: validName.valueOrNull!,
      status: ProjectStatus.idea,
      craft: craft,
      technique: chosen,
      contentKind: contentKind,
      notes: notes,
      coverPath: null,
      lastWorkedAt: _clock.now().toUtc(),
    );
    final Result<void> saved = await _repository.save(project);
    return saved.map((_) => project);
  }
}
