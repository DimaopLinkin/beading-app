import 'package:beading/core/clock.dart';
import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/work_sessions_dao.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:beading/domain/weaving/work_session.dart';
import 'package:beading/domain/weaving/work_session_repository.dart';
import 'package:drift/drift.dart';

/// Сессии работы в таблице `work_sessions`. Служебные колонки синхронизации ставит сам.
class DriftWorkSessionRepository implements WorkSessionRepository {
  DriftWorkSessionRepository({
    required WorkSessionsDao dao,
    required DeviceIdProvider deviceIds,
    required Clock clock,
    required IdGenerator ids,
  }) : _dao = dao,
       _deviceIds = deviceIds,
       _clock = clock,
       _ids = ids;

  final WorkSessionsDao _dao;
  final DeviceIdProvider _deviceIds;
  final Clock _clock;
  final IdGenerator _ids;

  @override
  Future<Result<WorkSession>> start(String projectId, DateTime startedAt) => _withDevice<WorkSession>((deviceId) async {
    final String id = _ids.next();
    final int now = _nowMs();
    await _dao.insertRow(
      WorkSessionsCompanion.insert(
        id: id,
        projectId: projectId,
        startedAt: startedAt.millisecondsSinceEpoch,
        createdAt: now,
        updatedAt: now,
        deviceId: deviceId,
      ),
    );
    return Success<WorkSession>(WorkSession(id: id, projectId: projectId, startedAt: startedAt.toUtc()));
  });

  @override
  Future<Result<void>> touch(String sessionId, DateTime endedAt) => _withDevice<void>((deviceId) async {
    final WorkSessionRow? row = await _dao.findAlive(sessionId);
    if (row == null) {
      return Err<void>(NotFoundFailure('Сессия $sessionId не найдена'));
    }
    // Часы могли откатиться: конец не раньше начала и не раньше уже записанного.
    final int end = [endedAt.millisecondsSinceEpoch, row.startedAt, row.endedAt ?? 0].reduce((a, b) => a > b ? a : b);
    await _dao.updateRow(
      sessionId,
      WorkSessionsCompanion(
        endedAt: Value<int?>(end),
        updatedAt: Value<int>(_nowMs()),
        deviceId: Value<String>(deviceId),
      ),
    );
    return const Success<void>(null);
  });

  @override
  Future<Result<void>> addAll(String projectId, List<WorkSession> sessions) => _withDevice<void>((deviceId) async {
    final int now = _nowMs();
    for (final WorkSession s in sessions) {
      await _dao.insertRow(
        WorkSessionsCompanion.insert(
          id: _ids.next(),
          projectId: projectId,
          startedAt: s.startedAt.millisecondsSinceEpoch,
          endedAt: Value<int?>(s.endedAt?.millisecondsSinceEpoch),
          createdAt: now,
          updatedAt: now,
          deviceId: deviceId,
        ),
      );
    }
    return const Success<void>(null);
  });

  @override
  Future<Result<List<WorkSession>>> byProject(String projectId) => guardStorage<List<WorkSession>>(
    () async => <WorkSession>[for (final WorkSessionRow row in await _dao.aliveByProject(projectId)) _toDomain(row)],
  );

  @override
  Future<Result<Duration>> totalFor(String projectId) async {
    final Result<List<WorkSession>> sessions = await byProject(projectId);
    return switch (sessions) {
      Err<List<WorkSession>>(:final failure) => Err<Duration>(failure),
      Success<List<WorkSession>>(:final value) => Success<Duration>(
        value.fold<Duration>(Duration.zero, (sum, s) => sum + s.duration),
      ),
    };
  }

  @override
  Future<Result<void>> deleteByProject(String projectId) => _withDevice<void>((deviceId) async {
    await _dao.tombstoneByProject(projectId: projectId, nowMs: _nowMs(), deviceId: deviceId);
    return const Success<void>(null);
  });

  int _nowMs() => _clock.now().millisecondsSinceEpoch;

  WorkSession _toDomain(WorkSessionRow row) => WorkSession(
    id: row.id,
    projectId: row.projectId,
    startedAt: DateTime.fromMillisecondsSinceEpoch(row.startedAt, isUtc: true),
    endedAt: row.endedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(row.endedAt!, isUtc: true),
  );

  Future<Result<T>> _withDevice<T>(Future<Result<T>> Function(String deviceId) action) async {
    final Result<String> deviceId = await _deviceIds.deviceId();
    if (deviceId case Err<String>(:final Failure failure)) {
      return Err<T>(failure);
    }
    final Result<Result<T>> guarded = await guardStorage<Result<T>>(() => action(deviceId.valueOrNull!));
    return guarded.fold(onSuccess: (inner) => inner, onFailure: Err<T>.new);
  }
}
