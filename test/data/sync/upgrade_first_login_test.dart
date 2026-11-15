import 'package:beading/core/id_generator.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/sync/drift_sync_store.dart';
import 'package:beading/data/sync/sync_entity_mapper.dart';
import 'package:beading/domain/sync/sync_engine.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain/sync/sync_fakes.dart';
import '../db/migration/app_database/generated/schema.dart';

/// Сценарий «Настя ведёт вышивку без входа, ставит обновление и входит в аккаунт»: ничего не теряется,
/// всё уходит в аккаунт, а второе устройство получает то же самое.
void main() {
  Future<SyncReport> sync(AppDatabase db, FakeRemote remote, String user) {
    final DriftSyncStore store = DriftSyncStore(
      ctx: SyncDbContext(db: db, ids: UuidV7IdGenerator()),
    );
    return SyncEngine(store: store, remote: remote, schema: store.schema).run(userId: user);
  }

  Future<List<String>> ids(AppDatabase db, String table) async => <String>[
    for (final Row r in await SyncDbContext(
      db: db,
      ids: UuidV7IdGenerator(),
    ).query('SELECT id FROM $table ORDER BY id'))
      r['id']! as String,
  ];

  test('данные, созданные до входа и пережившие миграцию, целиком уходят в аккаунт и появляются на втором устройстве', () async {
    final SchemaVerifier verifier = SchemaVerifier(GeneratedHelper());
    final InitializedSchema old = await verifier.schemaAt(15);
    for (final String statement in <String>[
      "INSERT INTO projects (id, created_at, updated_at, device_id, name, craft, technique, content_kind, last_worked_at) VALUES ('p1', 5, 5, 'd', 'Вышивка', 'cross_stitch', 't', 'grid', 1)",
      "INSERT INTO grid_patterns (id, created_at, updated_at, device_id, project_id, geometry, width, height, cell_metrics, cells, cells_codec_version) VALUES ('g1', 5, 5, 'd', 'p1', 'g', 2, 2, 'm', x'0102', 1)",
      "INSERT INTO pattern_colors (id, created_at, updated_at, device_id, grid_pattern_id, position, rgb, name, components) VALUES ('c1', 5, 5, 'd', 'g1', 0, 255, 'красный', '[]')",
      "INSERT INTO grid_progress_rows (id, created_at, updated_at, device_id, grid_pattern_id, row_index, completed_at) VALUES ('r1', 5, 5, 'd', 'g1', 3, 5)",
      "INSERT INTO grid_progress_cells (id, created_at, updated_at, device_id, grid_pattern_id, block_index, bits) VALUES ('k1', 5, 5, 'd', 'g1', 0, x'ff')",
      "INSERT INTO floss_stock (id, created_at, updated_at, device_id, brand, code, skeins) VALUES ('f1', 5, 5, 'd', 'dmc', '310', 2.0)",
    ]) {
      old.rawDatabase.execute(statement);
    }
    final AppDatabase phone = AppDatabase(old.newConnection());
    addTearDown(phone.close);
    await verifier.migrateAndValidate(phone, 16);

    final FakeRemote remote = FakeRemote();
    final SyncReport first = await sync(phone, remote, 'nastya');
    expect(first.pushed, greaterThanOrEqualTo(5), reason: 'всё, что было до входа, отправлено');
    expect(first.pulled, 0);

    // Своё на месте и после входа.
    expect(await ids(phone, 'projects'), <String>['p1']);
    expect(await ids(phone, 'grid_progress_rows'), <String>['r1']);
    expect(await ids(phone, 'floss_stock'), <String>['f1']);

    // Новое устройство с пустой базой получает всё.
    final AppDatabase mac = AppDatabase(NativeDatabase.memory());
    addTearDown(mac.close);
    final SyncReport second = await sync(mac, remote, 'nastya');
    expect(second.applied, greaterThanOrEqualTo(5));
    expect(await ids(mac, 'projects'), <String>['p1']);
    expect(await ids(mac, 'grid_patterns'), hasLength(1)); // id на новом устройстве свой, связь по проекту
    expect(await ids(mac, 'pattern_colors'), hasLength(1)); // id на новом устройстве свой, связь по проекту
    expect(await ids(mac, 'grid_progress_rows'), hasLength(1)); // id на новом устройстве свой, связь по проекту
    expect(await ids(mac, 'grid_progress_cells'), hasLength(1)); // id на новом устройстве свой, связь по проекту
    expect(await ids(mac, 'floss_stock'), hasLength(1));
  });

  test('вход в аккаунт, где уже есть другие данные: данные устройства не затираются, а добавляются', () async {
    final FakeRemote remote = FakeRemote();
    final AppDatabase other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await other.customStatement(
      "INSERT INTO projects (id, created_at, updated_at, device_id, name, technique, content_kind, last_worked_at) VALUES ('p-server', 9, 9, 'o', 'С сервера', 't', 'grid', 1)",
    );
    await sync(other, remote, 'nastya');

    final AppDatabase phone = AppDatabase(NativeDatabase.memory());
    addTearDown(phone.close);
    await phone.customStatement(
      "INSERT INTO projects (id, created_at, updated_at, device_id, name, technique, content_kind, last_worked_at) VALUES ('p-local', 5, 5, 'd', 'Своя', 't', 'grid', 1)",
    );
    await sync(phone, remote, 'nastya');
    await sync(other, remote, 'nastya');

    expect(await ids(phone, 'projects'), <String>['p-local', 'p-server']);
    expect(await ids(other, 'projects'), <String>['p-local', 'p-server']);
  });

  test('уже вошла в 0.3.0: после обновления и перезапуска правки, сделанные без сети, не теряются', () async {
    final FakeRemote remote = FakeRemote();
    final AppDatabase phone = AppDatabase(NativeDatabase.memory());
    final AppDatabase mac = AppDatabase(NativeDatabase.memory());
    addTearDown(phone.close);
    addTearDown(mac.close);
    String project(String id, String name) =>
        "INSERT INTO projects (id, created_at, updated_at, device_id, name, technique, content_kind, last_worked_at) VALUES ('$id', 5, 5, 'd', '$name', 't', 'grid', 1)";
    await phone.customStatement(project('p1', 'Вышивка'));
    await sync(phone, remote, 'nastya');
    await sync(mac, remote, 'nastya');

    // Без сети: правка на телефоне и новый проект; на маке в это время тоже правка.
    await phone.customStatement("UPDATE projects SET name = 'Вышивка 2', updated_at = 50 WHERE id = 'p1'");
    await phone.customStatement(project('p2', 'Новая'));
    await mac.customStatement(project('p3', 'С мака'));

    // «Перезапуск»: новые объекты движка на тех же базах, привязка и курсор сохранились.
    final SyncReport report = await sync(phone, remote, 'nastya');
    expect(report.pushed, 2);
    await sync(mac, remote, 'nastya');
    await sync(phone, remote, 'nastya');

    final List<Row> names = await SyncDbContext(db: mac, ids: UuidV7IdGenerator()).query(
      'SELECT id, name FROM projects WHERE deleted_at IS NULL ORDER BY id',
    );
    expect(<Object?>[for (final Row r in names) r['name']], <String>['Вышивка 2', 'Новая', 'С мака']);
    expect(await ids(phone, 'projects'), <String>['p1', 'p2', 'p3']);
  });
}
