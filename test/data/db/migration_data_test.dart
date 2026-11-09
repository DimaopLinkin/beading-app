import 'package:beading/data/db/app_database.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'migration/app_database/generated/schema.dart';

void main() {
  test('миграция v1→v2 сохраняет настройки и создаёт пустую таблицу projects', () async {
    final SchemaVerifier verifier = SchemaVerifier(GeneratedHelper());
    final InitializedSchema old = await verifier.schemaAt(1);
    old.rawDatabase.execute(
      "INSERT INTO settings (key, value, created_at, updated_at, device_id) VALUES ('themeMode', 'dark', 1, 1, 'd')",
    );

    final AppDatabase db = AppDatabase(old.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 2);

    final List<SettingRow> settings = await db.select(db.settings).get();
    expect(settings.single.value, 'dark');
    expect(await db.select(db.projects).get(), isEmpty);
  });
}
