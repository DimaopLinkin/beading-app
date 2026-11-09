import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_filter.dart';
import 'package:beading/domain/projects/project_repository.dart';

/// Проекты библиотеки по условиям [ProjectFilter], недавно открытые первыми.
class WatchProjects {
  const WatchProjects(this._repository);

  final ProjectRepository _repository;

  Stream<List<Project>> call({ProjectFilter filter = ProjectFilter.all}) =>
      _repository.watchAll().map((projects) => projects.where(filter.matches).toList(growable: false));
}
