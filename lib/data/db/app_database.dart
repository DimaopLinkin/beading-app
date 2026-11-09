import 'package:beading/data/db/app_database.steps.dart';
import 'package:beading/data/db/daos/projects_dao.dart';
import 'package:beading/data/db/daos/settings_dao.dart';
import 'package:beading/data/db/tables/projects_table.dart';
import 'package:beading/data/db/tables/settings_table.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Локальная база приложения — единственный источник правды на устройстве.
@DriftDatabase(tables: <Type>[Settings, Projects], daos: <Type>[SettingsDao, ProjectsDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.createTable(schema.projects);
      },
    ),
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
