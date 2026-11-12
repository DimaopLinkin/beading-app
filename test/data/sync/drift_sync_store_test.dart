import 'package:beading/core/id_generator.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/sync/drift_sync_store.dart';
import 'package:beading/data/sync/sync_entity_mapper.dart';
import 'package:beading/domain/sync/sync_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain/sync/sync_fakes.dart';

class _Device {
  _Device(this.name) : db = AppDatabase(NativeDatabase.memory()) {
    ctx = SyncDbContext(db: db, ids: UuidV7IdGenerator());
    store = DriftSyncStore(ctx: ctx);
  }

  final String name;
  final AppDatabase db;
  late final SyncDbContext ctx;
  late final DriftSyncStore store;

  Future<SyncReport> sync(FakeRemote remote) =>
      SyncEngine(store: store, remote: remote, schema: store.schema, pushBatch: 5).run(userId: 'nastya');

  Future<void> sql(String statement) => db.customStatement(statement);

  Future<Set<String>> outbox() async => <String>{
    for (final Row r in await ctx.query('SELECT entity, sync_id FROM sync_outbox')) "${r['entity']}/${r['sync_id']}",
  };

  Future<void> project(String id, {int at = 10, String name = 'Браслет'}) => sql(
    "INSERT INTO projects (id, created_at, updated_at, device_id, name, technique, content_kind, last_worked_at) VALUES ('$id', $at, $at, '$name-dev', '$name', 't', 'grid', 1)",
  );

  Future<void> grid(String id, String projectId, {int at = 10}) => sql(
    "INSERT INTO grid_patterns (id, created_at, updated_at, device_id, project_id, geometry, width, height, cell_metrics, cells, cells_codec_version) VALUES ('$id', $at, $at, '$name', '$projectId', 'g', 2, 2, 'm', x'0102', 1)",
  );

  Future<void> color(String id, String gridId, int position, {int at = 10}) => sql(
    "INSERT INTO pattern_colors (id, created_at, updated_at, device_id, grid_pattern_id, position, rgb, name, components) VALUES ('$id', $at, $at, '$name', '$gridId', $position, 255, 'красный', '[]')",
  );

  Future<void> progressRow(String id, String gridId, int row, {int at = 10}) => sql(
    "INSERT INTO grid_progress_rows (id, created_at, updated_at, device_id, grid_pattern_id, row_index, completed_at) VALUES ('$id', $at, $at, '$name', '$gridId', $row, $at)",
  );

  Future<void> cells(String id, String gridId, int block, {int at = 10}) => sql(
    "INSERT INTO grid_progress_cells (id, created_at, updated_at, device_id, grid_pattern_id, block_index, bits) VALUES ('$id', $at, $at, '$name', '$gridId', $block, x'ff')",
  );

  Future<List<Row>> rows(String sqlText) => ctx.query(sqlText);
}

void main() {
  late FakeRemote remote;
  late _Device phone;
  late _Device mac;

  setUp(() {
    remote = FakeRemote();
    phone = _Device('phone');
    mac = _Device('mac');
  });

  tearDown(() async {
    await phone.db.close();
    await mac.db.close();
  });

  Future<void> seedPhone() async {
    await phone.project('p1');
    await phone.grid('g1', 'p1');
    await phone.color('c0', 'g1', 0);
    await phone.color('c1', 'g1', 1);
    await phone.progressRow('r1', 'g1', 5);
    await phone.cells('b1', 'g1', 3);
    await phone.sql(
      "UPDATE grid_patterns SET current_row = 4, current_bead = 2, cursor_updated_at = 50, cursor_device_id = 'phone' WHERE id = 'g1'",
    );
    await phone.sql(
      "INSERT INTO floss_stock (id, created_at, updated_at, device_id, brand, code, skeins) VALUES ('f1', 1, 1, 'phone', 'dmc', '310', 2.5)",
    );
    await phone.sql(
      "INSERT INTO settings (\"key\", value, created_at, updated_at, device_id) VALUES ('theme', 'dark', 1, 1, 'phone')",
    );
    await phone.sql(
      "INSERT INTO settings (\"key\", value, created_at, updated_at, device_id) VALUES ('local.deviceId', 'phone-secret', 1, 1, 'phone')",
    );
    await phone.sql(
      "INSERT INTO work_sessions (id, created_at, updated_at, device_id, project_id, started_at, ended_at) VALUES ('ws1', 1, 1, 'phone', 'p1', 5, 9)",
    );
  }

  test(
    'первый вход: всё, что уже есть на устройстве, уходит на сервер, а на втором устройстве появляется целиком',
    () async {
      await seedPhone();
      // Данные «прошлой жизни» устройства: очередь пуста, их ставит в очередь первая привязка к аккаунту.
      await phone.sql('DELETE FROM sync_outbox');
      expect(await phone.outbox(), isEmpty);

      final SyncReport first = await phone.sync(remote);
      expect(first.pushed, 8);
      expect(await phone.outbox(), isEmpty);
      expect(
        remote.rows.keys,
        containsAll(<String>[
          'project/p1',
          'grid_pattern/p1',
          'grid_cursor/p1',
          'progress_row/p1:5',
          'progress_cell/p1:3',
          'floss_stock/dmc:310',
          'setting/theme',
          'work_session/ws1',
        ]),
      );
      expect(
        remote.rows.keys.where((k) => k.contains('local.')),
        isEmpty,
        reason: 'настройки устройства не уходят',
      );

      final SyncReport second = await mac.sync(remote);
      expect(second.applied, 8);
      expect(await mac.outbox(), isEmpty, reason: 'принятое не уходит обратно');

      final List<Row> grid = await mac.rows('SELECT * FROM grid_patterns');
      expect(grid.single['width'], 2);
      expect(grid.single['current_row'], 4);
      expect(grid.single['current_bead'], 2);
      expect(
        (await mac.rows('SELECT position, name FROM pattern_colors ORDER BY position')).map((r) => r['name']),
        <Object?>['красный', 'красный'],
      );
      expect((await mac.rows('SELECT row_index FROM grid_progress_rows')).single['row_index'], 5);
      expect((await mac.rows('SELECT block_index FROM grid_progress_cells')).single['block_index'], 3);
      expect((await mac.rows('SELECT skeins FROM floss_stock')).single['skeins'], 2.5);
      expect((await mac.rows('SELECT value FROM settings WHERE "key" = \'theme\'')).single['value'], 'dark');
      expect(
        await mac.rows('SELECT 1 FROM settings WHERE "key" = \'local.deviceId\' AND value = \'phone-secret\''),
        isEmpty,
      );
    },
  );

  test('локальные id у устройств разные, а ряды и клетки сходятся по ключу проекта', () async {
    await seedPhone();
    await phone.sync(remote);
    await mac.sync(remote);

    final String phoneGrid = (await phone.rows('SELECT id FROM grid_patterns')).single['id']! as String;
    final String macGrid = (await mac.rows('SELECT id FROM grid_patterns')).single['id']! as String;
    expect(macGrid, isNot(phoneGrid));

    // Оба отметили ряд 7 офлайн: на сервере одна запись, у обоих один ряд.
    await phone.progressRow('pr', phoneGrid, 7, at: 100);
    await mac.progressRow('mr', macGrid, 7, at: 200);
    await phone.sync(remote);
    await mac.sync(remote);
    await phone.sync(remote);

    for (final _Device d in <_Device>[phone, mac]) {
      expect(await d.rows('SELECT row_index FROM grid_progress_rows WHERE row_index = 7'), hasLength(1));
    }
    expect(remote.rows.keys.where((k) => k == 'progress_row/p1:7'), hasLength(1));
  });

  test('движение по ряду уходит записью grid_cursor и не пересылает сетку', () async {
    await seedPhone();
    await phone.sync(remote);
    await mac.sync(remote);
    final int gridSeq = remote.seqOf['grid_pattern/p1']!;

    final String phoneGrid = (await phone.rows('SELECT id FROM grid_patterns')).single['id']! as String;
    await phone.sql(
      "UPDATE grid_patterns SET current_row = 9, cursor_updated_at = 99, cursor_device_id = 'phone' WHERE id = '$phoneGrid'",
    );
    expect(await phone.outbox(), <String>{'grid_cursor/p1'});
    await phone.sync(remote);
    await mac.sync(remote);

    expect(remote.seqOf['grid_pattern/p1'], gridSeq);
    expect((await mac.rows('SELECT current_row FROM grid_patterns')).single['current_row'], 9);
  });

  test('удаление проекта на телефоне скрывает проект на Mac, ребёнок не показывается как живой', () async {
    await seedPhone();
    await phone.sync(remote);
    await mac.sync(remote);

    await phone.sql("UPDATE projects SET deleted_at = 500, updated_at = 500, device_id = 'phone' WHERE id = 'p1'");
    await phone.sync(remote);
    await mac.sync(remote);

    expect((await mac.rows('SELECT deleted_at FROM projects')).single['deleted_at'], 500);
  });

  test('поля из будущей версии формата не теряются при правке на этом устройстве (теневая копия)', () async {
    await seedPhone();
    await phone.sync(remote);
    await mac.sync(remote);
    // Сервер хранит запись проекта с неизвестным этому приложению полем.
    final r = remote.rows['project/p1']!;
    remote.rows['project/p1'] = r.copyWithData(
      <String, Object?>{...r.data, 'color_tag': 'red'},
      updatedAt: 300,
      deviceId: 'future',
    );
    remote.seqOf['project/p1'] = 1000;

    await mac.sync(remote);
    await mac.sql("UPDATE projects SET name = 'Новое имя', updated_at = 400, device_id = 'mac' WHERE id = 'p1'");
    await mac.sync(remote);

    expect(remote.rows['project/p1']!.data['name'], 'Новое имя');
    expect(remote.rows['project/p1']!.data['color_tag'], 'red');
  });

  test('чужой аккаунт: на устройстве данные Насти, вход под другим не стартует', () async {
    await phone.sync(remote);
    await expectLater(
      SyncEngine(store: phone.store, remote: remote, schema: phone.store.schema).run(userId: 'other'),
      throwsA(isA<SyncOwnerMismatch>()),
    );
  });

  test('схема из книги: страницы, состояние страницы и открытая страница доезжают с переводом локальных id', () async {
    await phone.project('p2', name: 'Книга');
    await phone.sql(
      "INSERT INTO image_patterns (id, created_at, updated_at, device_id, project_id) VALUES ('ip1', 1, 1, 'phone', 'p2')",
    );
    for (final int position in <int>[0, 1]) {
      await phone.sql(
        'INSERT INTO image_pattern_pages (id, created_at, updated_at, device_id, pattern_id, position, path, width, height) '
        "VALUES ('pg$position', 1, 1, 'phone', 'ip1', $position, 'a$position.png', 10, 20)",
      );
    }
    await phone.sql(
      'INSERT INTO page_work_states (id, created_at, updated_at, device_id, ruler_top, ruler_height, ruler_step, ruler_row, highlight, row_direction, view_scale, view_dx, view_dy, markup) '
      "VALUES ('pg1', 1, 7, 'phone', 1, 2, 2, 4, 'green', 'bottomUp', 1, 0, 0, x'0a')",
    );
    await phone.sql(
      "INSERT INTO book_work_states (id, created_at, updated_at, device_id, current_page_id) VALUES ('ip1', 1, 7, 'phone', 'pg1')",
    );

    await phone.sync(remote);
    await mac.sync(remote);

    expect(
      (await mac.rows('SELECT position, path FROM image_pattern_pages ORDER BY position')).map((r) => r['path']),
      <Object?>['a0.png', 'a1.png'],
    );
    final Row work = (await mac.rows(
      'SELECT w.ruler_row AS ruler_row, w.row_direction AS dir, p.position AS position FROM page_work_states w JOIN image_pattern_pages p ON p.id = w.id',
    )).single;
    expect((work['ruler_row'], work['dir'], work['position']), (4, 'bottomUp', 1));
    final Row book = (await mac.rows(
      'SELECT p.position AS position FROM book_work_states b JOIN image_pattern_pages p ON p.id = b.current_page_id',
    )).single;
    expect(book['position'], 1);
    expect(await mac.outbox(), isEmpty);
  });
}
