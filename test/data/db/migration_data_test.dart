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

  test('миграция v5→v6 не трогает схемы и страницы и создаёт пустые таблицы работы по схеме', () async {
    final SchemaVerifier verifier = SchemaVerifier(GeneratedHelper());
    final InitializedSchema old = await verifier.schemaAt(5);
    old.rawDatabase
      ..execute(
        'INSERT INTO projects (id, name, technique, content_kind, last_worked_at, created_at, updated_at, device_id) '
        "VALUES ('proj', 'П', 'loom', 'image', 0, 1, 1, 'd')",
      )
      ..execute(
        "INSERT INTO image_patterns (id, project_id, created_at, updated_at, device_id) VALUES ('pat', 'proj', 1, 1, 'd')",
      )
      ..execute(
        'INSERT INTO image_pattern_pages (id, pattern_id, position, path, width, height, created_at, updated_at, device_id) '
        "VALUES ('pg', 'pat', 0, 'a.png', 10, 20, 1, 1, 'd')",
      );

    final AppDatabase db = AppDatabase(old.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 6);

    expect((await db.select(db.imagePatternPages).get()).single.id, 'pg');
    expect(await db.select(db.pageWorkStates).get(), isEmpty);
    expect(await db.select(db.bookWorkStates).get(), isEmpty);
  });

  test('миграция v7→v8 сохраняет линейку, направление по умолчанию сверху вниз', () async {
    final SchemaVerifier verifier = SchemaVerifier(GeneratedHelper());
    final InitializedSchema old = await verifier.schemaAt(7);
    old.rawDatabase
      ..execute(
        'INSERT INTO projects (id, name, technique, content_kind, last_worked_at, created_at, updated_at, device_id) '
        "VALUES ('proj', 'П', 'loom', 'image', 0, 1, 1, 'd')",
      )
      ..execute(
        "INSERT INTO image_patterns (id, project_id, created_at, updated_at, device_id) VALUES ('pat', 'proj', 1, 1, 'd')",
      )
      ..execute(
        'INSERT INTO image_pattern_pages (id, pattern_id, position, path, width, height, created_at, updated_at, device_id) '
        "VALUES ('pg', 'pat', 0, 'a.png', 10, 20, 1, 1, 'd')",
      )
      ..execute(
        'INSERT INTO page_work_states (id, ruler_top, ruler_height, ruler_step, ruler_row, highlight, view_scale, view_dx, '
        "view_dy, created_at, updated_at, device_id) VALUES ('pg', 1, 2, 2, 4, 'green', 1, 0, 0, 1, 1, 'd')",
      );

    final AppDatabase db = AppDatabase(old.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 8);

    final PageWorkStateRow row = (await db.select(db.pageWorkStates).get()).single;
    expect(row.rulerRow, 4);
    expect(row.rowDirection, 'topDown');
  });
}
