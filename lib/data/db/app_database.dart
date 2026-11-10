import 'package:beading/data/db/app_database.steps.dart';
import 'package:beading/data/db/daos/catalog_dao.dart';
import 'package:beading/data/db/daos/easter_egg_log_dao.dart';
import 'package:beading/data/db/daos/image_patterns_dao.dart';
import 'package:beading/data/db/daos/projects_dao.dart';
import 'package:beading/data/db/daos/settings_dao.dart';
import 'package:beading/data/db/tables/catalog_tables.dart';
import 'package:beading/data/db/tables/easter_egg_log_table.dart';
import 'package:beading/data/db/tables/image_pattern_tables.dart';
import 'package:beading/data/db/tables/projects_table.dart';
import 'package:beading/data/db/tables/settings_table.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Локальная база приложения — единственный источник правды на устройстве.
@DriftDatabase(
  tables: <Type>[
    Settings,
    Projects,
    EasterEggLogEntries,
    ImagePatterns,
    ImagePatternPages,
    CatalogColors,
    CatalogSources,
  ],
  daos: <Type>[SettingsDao, ProjectsDao, EasterEggLogDao, ImagePatternsDao, CatalogDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.createTable(schema.projects);
      },
      // v3 (T08): история показов комплиментов.
      from2To3: (m, schema) => m.createTable(schema.easterEggLog),
      // v4 (T06): схемы-картинки из книг и их страницы.
      from3To4: (m, schema) async {
        await m.createTable(schema.imagePatterns);
        await m.createTable(schema.imagePatternPages);
      },
      // v5 (T13): каталог цветов.
      from4To5: (m, schema) async {
        await m.createTable(schema.catalogColors);
        await m.createTable(schema.catalogSources);
      },
    ),
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
