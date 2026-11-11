import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/weaving/work_session.dart';
import 'package:beading/domain/weaving/work_session_repository.dart';

/// Сессии работы в памяти.
class FakeWorkSessionRepository implements WorkSessionRepository {
  final Map<String, WorkSession> sessions = <String, WorkSession>{};
  final List<String> deletedProjects = <String>[];
  int _next = 0;

  /// Если `true`, `start` возвращает ошибку.
  bool failStart = false;

  @override
  Future<Result<WorkSession>> start(String projectId, DateTime startedAt) async {
    if (failStart) {
      return const Err<WorkSession>(StorageFailure('boom'));
    }
    final WorkSession session = WorkSession(id: 'ws-${++_next}', projectId: projectId, startedAt: startedAt);
    sessions[session.id] = session;
    return Success<WorkSession>(session);
  }

  @override
  Future<Result<void>> touch(String sessionId, DateTime endedAt) async {
    final WorkSession? old = sessions[sessionId];
    if (old == null) {
      return Err<void>(NotFoundFailure('нет сессии $sessionId'));
    }
    sessions[sessionId] = WorkSession(
      id: old.id,
      projectId: old.projectId,
      startedAt: old.startedAt,
      endedAt: endedAt,
    );
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> addAll(String projectId, List<WorkSession> added) async {
    for (final WorkSession s in added) {
      final WorkSession session = WorkSession(
        id: 'ws-${++_next}',
        projectId: projectId,
        startedAt: s.startedAt,
        endedAt: s.endedAt,
      );
      sessions[session.id] = session;
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<List<WorkSession>>> byProject(String projectId) async =>
      Success<List<WorkSession>>(sessions.values.where((s) => s.projectId == projectId).toList());

  @override
  Future<Result<Duration>> totalFor(String projectId) async => Success<Duration>(
    sessions.values.where((s) => s.projectId == projectId).fold<Duration>(Duration.zero, (a, s) => a + s.duration),
  );

  @override
  Future<Result<void>> deleteByProject(String projectId) async {
    deletedProjects.add(projectId);
    sessions.removeWhere((_, s) => s.projectId == projectId);
    return const Success<void>(null);
  }
}
