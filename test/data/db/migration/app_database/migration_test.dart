import 'package:beading/data/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

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
}
