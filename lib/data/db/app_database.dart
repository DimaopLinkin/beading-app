import 'package:beading/data/db/app_database.steps.dart';
import 'package:beading/data/db/daos/book_work_dao.dart';
import 'package:beading/data/db/daos/catalog_dao.dart';
import 'package:beading/data/db/daos/easter_egg_log_dao.dart';
import 'package:beading/data/db/daos/grid_patterns_dao.dart';
import 'package:beading/data/db/daos/image_patterns_dao.dart';
import 'package:beading/data/db/daos/projects_dao.dart';
import 'package:beading/data/db/daos/settings_dao.dart';
import 'package:beading/data/db/daos/work_sessions_dao.dart';
import 'package:beading/data/db/tables/book_work_tables.dart';
import 'package:beading/data/db/tables/catalog_tables.dart';
import 'package:beading/data/db/tables/easter_egg_log_table.dart';
import 'package:beading/data/db/tables/grid_pattern_tables.dart';
import 'package:beading/data/db/tables/image_pattern_tables.dart';
import 'package:beading/data/db/tables/projects_table.dart';
import 'package:beading/data/db/tables/settings_table.dart';
import 'package:beading/data/db/tables/work_sessions_table.dart';
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
    GridPatterns,
    PatternColors,
    GridProgressRows,
    CatalogColors,
    CatalogSources,
    PageWorkStates,
    BookWorkStates,
    WorkSessions,
  ],
  daos: <Type>[
    SettingsDao,
    ProjectsDao,
    EasterEggLogDao,
    ImagePatternsDao,
    GridPatternsDao,
    CatalogDao,
    BookWorkDao,
    WorkSessionsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 10;

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
      // v6 (T07): линейка и вид страниц схемы из книги, открытая страница.
      from5To6: (m, schema) async {
        await m.createTable(schema.pageWorkStates);
        await m.createTable(schema.bookWorkStates);
      },
      // v7 (T14): сеточные схемы, их палитры и отметки рядов.
      from6To7: (m, schema) async {
        await m.createTable(schema.gridPatterns);
        await m.createTable(schema.patternColors);
        await m.createTable(schema.gridProgressRows);
      },
      // v8 (M1-design-align): направление рядов линейки.
      from7To8: (m, schema) async {
        await m.addColumn(schema.pageWorkStates, schema.pageWorkStates.rowDirection);
      },
      // v9 (T19): сессии работы над проектом.
      from8To9: (m, schema) => m.createTable(schema.workSessions),
      // v10 (B02): зона схемы на странице и число рядов в ней.
      from9To10: (m, schema) async {
        await m.addColumn(schema.pageWorkStates, schema.pageWorkStates.zoneTop);
        await m.addColumn(schema.pageWorkStates, schema.pageWorkStates.zoneBottom);
        await m.addColumn(schema.pageWorkStates, schema.pageWorkStates.zoneLeft);
        await m.addColumn(schema.pageWorkStates, schema.pageWorkStates.zoneRight);
        await m.addColumn(schema.pageWorkStates, schema.pageWorkStates.rowCount);
      },
    ),
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
