import 'package:beading/data/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('SELECT 1');
  });

  tearDown(() => db.close());

  Future<Set<String>> outbox() async {
    final rows = await db.customSelect('SELECT entity, sync_id FROM sync_outbox').get();
    return rows.map((r) => '${r.read<String>('entity')}/${r.read<String>('sync_id')}').toSet();
  }

  Future<void> clearOutbox() => db.customStatement('DELETE FROM sync_outbox');

  Future<void> project(String id) => db.customStatement(
    "INSERT INTO projects (id, created_at, updated_at, device_id, name, technique, content_kind, last_worked_at) VALUES ('$id', 1, 1, 'd', 'n', 't', 'grid', 1)",
  );

  Future<void> grid(String id, String projectId) => db.customStatement(
    "INSERT INTO grid_patterns (id, created_at, updated_at, device_id, project_id, geometry, width, height, cell_metrics, cells, cells_codec_version) VALUES ('$id', 1, 1, 'd', '$projectId', 'g', 2, 2, 'm', x'00', 1)",
  );

  test('новая и изменённая запись попадают в очередь с ключом слияния', () async {
    await project('p1');
    expect(await outbox(), <String>{'project/p1'});
    await clearOutbox();
    await db.customStatement("UPDATE projects SET name = 'x' WHERE id = 'p1'");
    expect(await outbox(), <String>{'project/p1'});
  });

  test('повторная правка не плодит строки очереди', () async {
    await project('p1');
    await db.customStatement("UPDATE projects SET name = 'a' WHERE id = 'p1'");
    await db.customStatement("UPDATE projects SET name = 'b' WHERE id = 'p1'");
    expect(await outbox(), hasLength(1));
  });

  test('пока идёт применение входящих, очередь молчит', () async {
    await db.customStatement('INSERT INTO sync_applying (flag) VALUES (1)');
    await project('p1');
    await db.customStatement('DELETE FROM sync_applying');
    expect(await outbox(), isEmpty);
  });

  test('настройки: local.* не синхронизируются, остальные да', () async {
    await db.customStatement(
      "INSERT INTO settings (\"key\", value, created_at, updated_at, device_id) VALUES ('local.deviceId', 'x', 1, 1, 'd')",
    );
    await db.customStatement(
      "INSERT INTO settings (\"key\", value, created_at, updated_at, device_id) VALUES ('theme', 'dark', 1, 1, 'd')",
    );
    await db.customStatement("UPDATE settings SET value = 'light' WHERE \"key\" = 'theme'");
    await db.customStatement("UPDATE settings SET value = 'y' WHERE \"key\" = 'local.deviceId'");
    expect(await outbox(), <String>{'setting/theme'});
  });

  test('схема: ключ по проекту; движение «остановилась здесь» ставит grid_cursor, но не пересылает сетку', () async {
    await project('p1');
    await grid('g1', 'p1');
    expect(await outbox(), containsAll(<String>['grid_pattern/p1', 'grid_cursor/p1']));
    await clearOutbox();

    await db.customStatement("UPDATE grid_patterns SET current_row = 5, updated_at = 9 WHERE id = 'g1'");
    expect(await outbox(), <String>{'grid_cursor/p1'});

    await clearOutbox();
    await db.customStatement("UPDATE grid_patterns SET width = 3 WHERE id = 'g1'");
    expect(await outbox(), <String>{'grid_pattern/p1'});
  });

  test('палитра, ряды и клетки привязываются к проекту, а не к локальному id схемы', () async {
    await project('p1');
    await grid('g1', 'p1');
    await clearOutbox();

    await db.customStatement(
      "INSERT INTO pattern_colors (id, created_at, updated_at, device_id, grid_pattern_id, position, rgb, name, components) VALUES ('c1', 1, 1, 'd', 'g1', 0, 1, 'n', '[]')",
    );
    await db.customStatement(
      "INSERT INTO grid_progress_rows (id, created_at, updated_at, device_id, grid_pattern_id, row_index, completed_at) VALUES ('r1', 1, 1, 'd', 'g1', 5, 1)",
    );
    await db.customStatement(
      "INSERT INTO grid_progress_cells (id, created_at, updated_at, device_id, grid_pattern_id, block_index, bits) VALUES ('b1', 1, 1, 'd', 'g1', 7, x'00')",
    );
    expect(await outbox(), <String>{'grid_pattern/p1', 'progress_row/p1:5', 'progress_cell/p1:7'});
  });

  test('запас мулине: ключ — бренд и номер', () async {
    await db.customStatement(
      "INSERT INTO floss_stock (id, created_at, updated_at, device_id, brand, code, skeins) VALUES ('f1', 1, 1, 'd', 'dmc', '310', 2.0)",
    );
    expect(await outbox(), <String>{'floss_stock/dmc:310'});
  });

  test('сброс данных схемы через замену строки тоже попадает в очередь (надгробие)', () async {
    await project('p1');
    await grid('g1', 'p1');
    await clearOutbox();
    await db.customStatement("UPDATE grid_patterns SET deleted_at = 5 WHERE id = 'g1'");
    expect(await outbox(), <String>{'grid_pattern/p1', 'grid_cursor/p1'});
  });
}
