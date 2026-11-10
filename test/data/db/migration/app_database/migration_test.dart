import 'package:beading/data/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v6.dart' as v6;
import 'generated/schema_v7.dart' as v7;
import 'generated/schema_v8.dart' as v8;
import 'generated/schema_v9.dart' as v9;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test('миграция v2 → v3 сохраняет настройки и создаёт пустую easter_egg_log', () async {
    final oldSettingsData = <v2.SettingsData>[
      const v2.SettingsData(
        key: 'userName',
        value: 'Маша',
        createdAt: 1,
        updatedAt: 2,
        deviceId: 'device-a',
      ),
    ];
    final expectedNewSettingsData = <v3.SettingsData>[
      const v3.SettingsData(
        key: 'userName',
        value: 'Маша',
        createdAt: 1,
        updatedAt: 2,
        deviceId: 'device-a',
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.settings, oldSettingsData);
      },
      validateItems: (newDb) async {
        expect(
          expectedNewSettingsData,
          await newDb.select(newDb.settings).get(),
        );
        expect(await newDb.select(newDb.easterEggLog).get(), isEmpty);
      },
    );
  });

  test('миграция v3 → v4 сохраняет проекты и создаёт пустые таблицы схем-картинок', () async {
    const oldProjects = <v3.ProjectsData>[
      v3.ProjectsData(
        id: 'p1',
        name: 'Браслет',
        craft: 'beading',
        status: 'idea',
        technique: 'loom',
        contentKind: 'image',
        notes: '',
        lastWorkedAt: 5,
        createdAt: 1,
        updatedAt: 2,
        deviceId: 'device-a',
      ),
    ];
    const expectedProjects = <v4.ProjectsData>[
      v4.ProjectsData(
        id: 'p1',
        name: 'Браслет',
        craft: 'beading',
        status: 'idea',
        technique: 'loom',
        contentKind: 'image',
        notes: '',
        lastWorkedAt: 5,
        createdAt: 1,
        updatedAt: 2,
        deviceId: 'device-a',
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 3,
      newVersion: 4,
      createOld: v3.DatabaseAtV3.new,
      createNew: v4.DatabaseAtV4.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.projects, oldProjects);
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.projects).get(), expectedProjects);
        expect(await newDb.select(newDb.imagePatterns).get(), isEmpty);
        expect(await newDb.select(newDb.imagePatternPages).get(), isEmpty);
      },
    );
  });

  test('миграция v6 → v7 сохраняет проекты и каталог, создаёт пустые таблицы сеточных схем', () async {
    const oldProjects = <v6.ProjectsData>[
      v6.ProjectsData(
        id: 'p1',
        name: 'Браслет',
        craft: 'beading',
        status: 'idea',
        technique: 'loom',
        contentKind: 'grid',
        notes: '',
        lastWorkedAt: 5,
        createdAt: 1,
        updatedAt: 2,
        deviceId: 'device-a',
      ),
    ];
    const expectedProjects = <v7.ProjectsData>[
      v7.ProjectsData(
        id: 'p1',
        name: 'Браслет',
        craft: 'beading',
        status: 'idea',
        technique: 'loom',
        contentKind: 'grid',
        notes: '',
        lastWorkedAt: 5,
        createdAt: 1,
        updatedAt: 2,
        deviceId: 'device-a',
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 6,
      newVersion: 7,
      createOld: v6.DatabaseAtV6.new,
      createNew: v7.DatabaseAtV7.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.projects, oldProjects);
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.projects).get(), expectedProjects);
        expect(await newDb.select(newDb.gridPatterns).get(), isEmpty);
        expect(await newDb.select(newDb.patternColors).get(), isEmpty);
        expect(await newDb.select(newDb.gridProgressRows).get(), isEmpty);
      },
    );
  });

  test('миграция v8 → v9 сохраняет проекты и создаёт пустую таблицу сессий работы', () async {
    const projects = <v8.ProjectsData>[
      v8.ProjectsData(
        id: 'p1',
        name: 'Браслет',
        craft: 'beading',
        status: 'idea',
        technique: 'loom',
        contentKind: 'grid',
        notes: '',
        lastWorkedAt: 5,
        createdAt: 1,
        updatedAt: 2,
        deviceId: 'device-a',
      ),
    ];
    const expected = <v9.ProjectsData>[
      v9.ProjectsData(
        id: 'p1',
        name: 'Браслет',
        craft: 'beading',
        status: 'idea',
        technique: 'loom',
        contentKind: 'grid',
        notes: '',
        lastWorkedAt: 5,
        createdAt: 1,
        updatedAt: 2,
        deviceId: 'device-a',
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 8,
      newVersion: 9,
      createOld: v8.DatabaseAtV8.new,
      createNew: v9.DatabaseAtV9.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.projects, projects);
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.projects).get(), expected);
        expect(await newDb.select(newDb.workSessions).get(), isEmpty);
      },
    );
  });
}
