import 'dart:async';

import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';

/// Фейк хранилища проектов в памяти. [failNextWrite] заставляет следующую запись вернуть ошибку.
class FakeProjectRepository implements ProjectRepository {
  final Map<String, Project> projects = <String, Project>{};
  final Set<String> deleted = <String>{};
  final StreamController<void> _changes = StreamController<void>.broadcast(sync: true);
  Failure? failNextWrite;

  List<Project> get _sorted =>
      projects.values.where((p) => !deleted.contains(p.id)).toList()
        ..sort((a, b) => b.lastWorkedAt.compareTo(a.lastWorkedAt));

  @override
  Stream<List<Project>> watchAll() async* {
    yield _sorted;
    await for (final void _ in _changes.stream) {
      yield _sorted;
    }
  }

  @override
  Future<Result<Project>> get(String id) async {
    final Project? project = projects[id];
    if (project == null || deleted.contains(id)) {
      return Err<Project>(NotFoundFailure('нет проекта $id'));
    }
    return Success<Project>(project);
  }

  @override
  Future<Result<void>> save(Project project) async {
    final Failure? failure = failNextWrite;
    if (failure != null) {
      failNextWrite = null;
      return Err<void>(failure);
    }
    projects[project.id] = project;
    _changes.add(null);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> delete(String id) async {
    if (!projects.containsKey(id) || deleted.contains(id)) {
      return Err<void>(NotFoundFailure('нет проекта $id'));
    }
    deleted.add(id);
    _changes.add(null);
    return const Success<void>(null);
  }
}

/// Выдаёт id `id-1`, `id-2`, …
class FakeIdGenerator implements IdGenerator {
  int _counter = 0;

  @override
  String next() => 'id-${++_counter}';
}
