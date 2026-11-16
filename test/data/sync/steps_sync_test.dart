import 'dart:typed_data';

import 'package:beading/core/id_generator.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/sync/drift_sync_store.dart';
import 'package:beading/data/sync/sync_entity_mapper.dart';
import 'package:beading/domain/sync/sync_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain/sync/sync_fakes.dart';

/// Инструкции между двумя устройствами (T33b): документ, картинки с тем же id, курсор отдельной записью.
void main() {
  late FakeRemote remote;
  late AppDatabase phone;
  late AppDatabase mac;

  Future<SyncReport> sync(AppDatabase db) {
    final DriftSyncStore store = DriftSyncStore(
      ctx: SyncDbContext(db: db, ids: UuidV7IdGenerator()),
    );
    return SyncEngine(store: store, remote: remote, schema: store.schema).run(userId: 'nastya');
  }

  Future<List<Row>> rows(AppDatabase db, String sql) => SyncDbContext(db: db, ids: UuidV7IdGenerator()).query(sql);

  Future<void> seedPhone() async {
    for (final String sql in <String>[
      "INSERT INTO projects (id, created_at, updated_at, device_id, name, technique, content_kind, last_worked_at) VALUES ('p1', 5, 5, 'd', 'Жгут', 'offLoom', 'steps', 1)",
      "INSERT INTO step_patterns (id, created_at, updated_at, device_id, project_id, body, body_version, template_id) VALUES ('sp-phone', 5, 5, 'd', 'p1', '{\"v\":1}', 1, 'raw')",
      "INSERT INTO step_images (id, created_at, updated_at, device_id, pattern_id, path, width, height) VALUES ('img-1', 5, 5, 'd', 'sp-phone', 'step_patterns/sp-phone/img-1.png', 10, 20)",
      "INSERT INTO step_progress (id, created_at, updated_at, device_id, section_id, section_pass, step_id, step_pass, finished) VALUES ('sp-phone', 5, 5, 'd', 'a', 1, 's1', 1, 0)",
    ]) {
      await phone.customStatement(sql);
    }
  }

  setUp(() {
    remote = FakeRemote();
    phone = AppDatabase(NativeDatabase.memory());
    mac = AppDatabase(NativeDatabase.memory());
    addTearDown(phone.close);
    addTearDown(mac.close);
  });

  test('инструкция, картинка и курсор доезжают до второго устройства, id картинки сохраняется', () async {
    await seedPhone();
    final SyncReport first = await sync(phone);
    expect(first.pushed, greaterThanOrEqualTo(4));

    await sync(mac);

    final Row pattern = (await rows(mac, 'SELECT * FROM step_patterns')).single;
    expect(pattern['project_id'], 'p1');
    expect(pattern['id'], isNot('sp-phone'), reason: 'id инструкции на втором устройстве свой');
    expect(pattern['body'], '{"v":1}');
    expect(pattern['template_id'], 'raw');
    final Row image = (await rows(mac, 'SELECT * FROM step_images')).single;
    expect(image['id'], 'img-1', reason: 'документ ссылается на картинку по id');
    expect(image['pattern_id'], pattern['id']);
    final Row progress = (await rows(mac, 'SELECT * FROM step_progress')).single;
    expect(progress['id'], pattern['id']);
    expect(progress['step_id'], 's1');
  });

  test('«дальше» отправляет только курсор, документ не пересылается', () async {
    await seedPhone();
    await sync(phone);
    await sync(mac);

    await phone.customStatement(
      "UPDATE step_progress SET step_pass = 2, updated_at = 50, device_id = 'd' WHERE id = 'sp-phone'",
    );
    final SyncReport report = await sync(phone);
    expect(report.pushed, 1);

    await sync(mac);
    expect((await rows(mac, 'SELECT step_pass FROM step_progress')).single['step_pass'], 2);
  });

  test('правка документа и удаление картинки доезжают, удаление проекта убирает всё', () async {
    await seedPhone();
    await sync(phone);
    await sync(mac);

    await phone.customStatement(
      "UPDATE step_patterns SET body = '{\"v\":1,\"x\":1}', updated_at = 60 WHERE id = 'sp-phone'",
    );
    await phone.customStatement("UPDATE step_images SET deleted_at = 61, updated_at = 61 WHERE id = 'img-1'");
    await sync(phone);
    await sync(mac);

    expect((await rows(mac, 'SELECT body FROM step_patterns')).single['body'], '{"v":1,"x":1}');
    expect((await rows(mac, 'SELECT deleted_at FROM step_images')).single['deleted_at'], isNotNull);

    for (final String t in <String>['step_progress', 'step_images', 'step_patterns']) {
      await phone.customStatement('UPDATE $t SET deleted_at = 70, updated_at = 70');
    }
    await sync(phone);
    await sync(mac);
    for (final String t in <String>['step_progress', 'step_images', 'step_patterns']) {
      expect((await rows(mac, 'SELECT deleted_at FROM $t')).single['deleted_at'], isNotNull, reason: t);
    }
  });

  test('картинка приходит раньше документа: порядок применения по рангам, ничего не теряется', () async {
    await seedPhone();
    await sync(phone);
    final Uint8List unused = Uint8List(0);
    expect(unused, isEmpty);

    // Второе устройство впервые получает всё сразу: родитель применяется раньше детей.
    await sync(mac);
    expect(await rows(mac, 'SELECT id FROM step_images'), hasLength(1));
  });
}
