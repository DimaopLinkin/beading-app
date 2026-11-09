import 'package:beading/data/db/app_database.steps.dart';
import 'package:beading/data/db/daos/easter_egg_log_dao.dart';
import 'package:beading/data/db/daos/settings_dao.dart';
import 'package:beading/data/db/tables/easter_egg_log_table.dart';
import 'package:beading/data/db/tables/settings_table.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Локальная база приложения — единственный источник правды на устройстве.
@DriftDatabase(tables: <Type>[Settings, EasterEggLogEntries], daos: <Type>[SettingsDao, EasterEggLogDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: stepByStep(
      // v2 (T08): история показов комплиментов.
      from1To2: (m, schema) => m.createTable(schema.easterEggLog),
    ),
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
