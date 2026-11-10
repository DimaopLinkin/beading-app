import 'package:beading/core/clock.dart';
import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/projects_dao.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:drift/drift.dart';

/// Проекты в таблице `projects`. Сам ставит `created_at`, `updated_at` и `device_id`.
class DriftProjectRepository implements ProjectRepository {
  DriftProjectRepository({required ProjectsDao dao, required DeviceIdProvider deviceIds, required Clock clock})
    : _dao = dao,
      _deviceIds = deviceIds,
      _clock = clock;

  final ProjectsDao _dao;
  final DeviceIdProvider _deviceIds;
  final Clock _clock;

  @override
  Stream<List<Project>> watchAll() => _dao.watchAlive().map((rows) => rows.map(_toDomain).toList(growable: false));

  @override
  Future<Result<Project>> get(String id) => guardStorage<Result<Project>>(() async {
    final ProjectRow? row = await _dao.find(id);
    if (row == null || row.deletedAt != null) {
      return Err<Project>(NotFoundFailure('Проект $id не найден'));
    }
    return Success<Project>(_toDomain(row));
  }).then((guarded) => guarded.fold(onSuccess: (inner) => inner, onFailure: Err<Project>.new));

  @override
  Future<Result<void>> save(Project project) => _withDeviceId(
    (deviceId) => guardStorage<Result<void>>(() async {
      final int now = _nowMs();
      final ProjectRow? existing = await _dao.find(project.id);
      if (existing == null) {
        await _dao.insertRow(
          ProjectsCompanion.insert(
            id: project.id,
            name: project.name,
            craft: Value<String>(project.craft.name),
            status: Value<String>(project.status.name),
            technique: project.technique.name,
            contentKind: project.contentKind.name,
            notes: Value<String>(project.notes),
            coverPath: Value<String?>(project.coverPath),
            lastWorkedAt: project.lastWorkedAt.millisecondsSinceEpoch,
            createdAt: now,
            updatedAt: now,
            deviceId: deviceId,
          ),
        );
        return const Success<void>(null);
      }
      if (existing.deletedAt != null) {
        return Err<void>(NotFoundFailure('Проект ${project.id} удалён'));
      }
      await _dao.updateRow(
        project.id,
        ProjectsCompanion(
          name: Value<String>(project.name),
          craft: Value<String>(project.craft.name),
          status: Value<String>(project.status.name),
          technique: Value<String>(project.technique.name),
          contentKind: Value<String>(project.contentKind.name),
          notes: Value<String>(project.notes),
          coverPath: Value<String?>(project.coverPath),
          lastWorkedAt: Value<int>(project.lastWorkedAt.millisecondsSinceEpoch),
          updatedAt: Value<int>(now),
          deviceId: Value<String>(deviceId),
        ),
      );
      return const Success<void>(null);
    }).then(_flatten),
  );

  @override
  Future<Result<void>> delete(String id) => _withDeviceId(
    (deviceId) => guardStorage<Result<void>>(() async {
      final int changed = await _dao.tombstone(id: id, nowMs: _nowMs(), deviceId: deviceId);
      return changed == 0 ? Err<void>(NotFoundFailure('Проект $id не найден')) : const Success<void>(null);
    }).then(_flatten),
  );

  int _nowMs() => _clock.now().millisecondsSinceEpoch;

  Result<void> _flatten(Result<Result<void>> guarded) =>
      guarded.fold(onSuccess: (inner) => inner, onFailure: Err<void>.new);

  Future<Result<void>> _withDeviceId(Future<Result<void>> Function(String deviceId) action) async {
    final Result<String> id = await _deviceIds.deviceId();
    return switch (id) {
      Err<String>(:final failure) => Err<void>(failure),
      Success<String>(:final String value) => action(value),
    };
  }

  /// Неизвестные значения (например, от более новой версии приложения) заменяем безопасными, а не роняем список.
  Project _toDomain(ProjectRow row) {
    final Craft craft = Craft.values.asNameMap()[row.craft] ?? Craft.beading;
    final Technique technique = Technique.values.asNameMap()[row.technique] ?? Technique.defaultFor(craft);
    return Project(
      id: row.id,
      name: row.name,
      status: ProjectStatus.values.asNameMap()[row.status] ?? ProjectStatus.idea,
      craft: craft,
      technique: technique.craft == craft ? technique : Technique.defaultFor(craft),
      contentKind: ContentKind.values.asNameMap()[row.contentKind] ?? ContentKind.image,
      notes: row.notes,
      coverPath: row.coverPath,
      lastWorkedAt: DateTime.fromMillisecondsSinceEpoch(row.lastWorkedAt, isUtc: true),
    );
  }
}
