import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/tables/work_sessions_table.dart';
import 'package:drift/drift.dart';

part 'work_sessions_dao.g.dart';

@DriftAccessor(tables: <Type>[WorkSessions])
class WorkSessionsDao extends DatabaseAccessor<AppDatabase> with _$WorkSessionsDaoMixin {
  WorkSessionsDao(super.attachedDatabase);

  Future<void> insertRow(WorkSessionsCompanion row) => into(workSessions).insert(row);

  Future<WorkSessionRow?> findAlive(String id) =>
      (select(workSessions)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  Future<void> updateRow(String id, WorkSessionsCompanion changes) =>
      (update(workSessions)..where((t) => t.id.equals(id))).write(changes);

  /// Живые сессии проекта по порядку начала.
  Future<List<WorkSessionRow>> aliveByProject(String projectId) =>
      (select(workSessions)
            ..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull())
            ..orderBy(<OrderingTerm Function($WorkSessionsTable)>[
              (t) => OrderingTerm.asc(t.startedAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();

  Future<int> tombstoneByProject({required String projectId, required int nowMs, required String deviceId}) =>
      (update(workSessions)..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull())).write(
        WorkSessionsCompanion(
          updatedAt: Value<int>(nowMs),
          deletedAt: Value<int?>(nowMs),
          deviceId: Value<String>(deviceId),
        ),
      );
}
