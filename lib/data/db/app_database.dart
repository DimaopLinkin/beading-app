import 'package:beading/data/db/daos/settings_dao.dart';
import 'package:beading/data/db/tables/settings_table.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Локальная база приложения — единственный источник правды на устройстве.
@DriftDatabase(tables: <Type>[Settings], daos: <Type>[SettingsDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // Шаги миграций (`stepByStep` из `make-migrations`) добавляются здесь при `schemaVersion++`.
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
