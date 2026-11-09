import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/tables/projects_table.dart';
import 'package:drift/drift.dart';

part 'projects_dao.g.dart';

@DriftAccessor(tables: <Type>[Projects])
class ProjectsDao extends DatabaseAccessor<AppDatabase> with _$ProjectsDaoMixin {
  ProjectsDao(super.attachedDatabase);

  /// Живые проекты: недавно открытые первыми, при равенстве — более новый id (UUID v7 растёт со временем).
  Stream<List<ProjectRow>> watchAlive() =>
      (select(projects)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy(<OrderingTerm Function($ProjectsTable)>[
              (t) => OrderingTerm.desc(t.lastWorkedAt),
              (t) => OrderingTerm.desc(t.id),
            ]))
          .watch();

  /// Строка по id, включая удалённую (с надгробием).
  Future<ProjectRow?> find(String id) => (select(projects)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertRow(ProjectsCompanion row) => into(projects).insert(row);

  Future<void> updateRow(String id, ProjectsCompanion changes) =>
      (update(projects)..where((t) => t.id.equals(id))).write(changes);

  /// Ставит надгробие живой строке; возвращает число затронутых строк.
  Future<int> tombstone({required String id, required int nowMs, required String deviceId}) =>
      (update(projects)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
        ProjectsCompanion(
          updatedAt: Value<int>(nowMs),
          deletedAt: Value<int?>(nowMs),
          deviceId: Value<String>(deviceId),
        ),
      );
}
