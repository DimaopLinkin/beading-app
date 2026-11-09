import 'package:beading/core/clock.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_content_cloner.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/project_name.dart';

/// Копия проекта: новое название «… (копия)», статус «идея», обложки нет, заметки сохраняются.
/// Содержимое копируют [ProjectContentCloner]-ы; если копирование не удалось, копия убирается.
class DuplicateProject {
  const DuplicateProject({
    required ProjectRepository repository,
    required IdGenerator ids,
    required Clock clock,
    List<ProjectContentCloner> cloners = const <ProjectContentCloner>[],
  }) : _repository = repository,
       _ids = ids,
       _clock = clock,
       _cloners = cloners;

  static const String copySuffix = ' (копия)';

  final ProjectRepository _repository;
  final IdGenerator _ids;
  final Clock _clock;
  final List<ProjectContentCloner> _cloners;

  Future<Result<Project>> call(String id) async {
    final Result<Project> found = await _repository.get(id);
    if (found case Err<Project>()) {
      return found;
    }
    final Project source = found.valueOrNull!;
    final String base = source.name.length + copySuffix.length > maxProjectNameLength
        ? source.name.substring(0, maxProjectNameLength - copySuffix.length)
        : source.name;
    final Project copy = Project(
      id: _ids.next(),
      name: '$base$copySuffix',
      status: ProjectStatus.idea,
      craft: source.craft,
      technique: source.technique,
      contentKind: source.contentKind,
      notes: source.notes,
      coverPath: null,
      lastWorkedAt: _clock.now().toUtc(),
    );
    final Result<void> saved = await _repository.save(copy);
    if (saved case Err<void>(:final failure)) {
      return Err<Project>(failure);
    }
    for (final ProjectContentCloner cloner in _cloners.where((c) => c.supports(source.contentKind))) {
      final Result<void> cloned = await cloner.clone(source: source, targetId: copy.id);
      if (cloned case Err<void>(:final failure)) {
        await _repository.delete(copy.id);
        return Err<Project>(failure);
      }
    }
    return Success<Project>(copy);
  }
}
