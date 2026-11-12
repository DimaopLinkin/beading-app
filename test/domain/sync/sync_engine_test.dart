import 'package:beading/domain/sync/sync_engine.dart';
import 'package:beading/domain/sync/sync_record.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_fakes.dart';

void main() {
  late FakeRemote remote;
  late FakeStore phone;
  late FakeStore mac;

  SyncEngine engineOf(FakeStore store, {int projectVersion = 1}) => SyncEngine(
    store: store,
    remote: remote,
    schema: testSchema(projectVersion: projectVersion),
    pushBatch: 2,
  );

  setUp(() {
    remote = FakeRemote();
    phone = FakeStore();
    mac = FakeStore();
  });

  test('два устройства сходятся: правка телефона доезжает до Mac', () async {
    phone.edit(rec('project', 'p1', at: 10, data: <String, Object?>{'name': 'Браслет'}));
    final SyncReport first = await engineOf(phone).run(userId: 'u');
    expect(first.pushed, 1);

    final SyncReport second = await engineOf(mac).run(userId: 'u');
    expect(second.applied, 1);
    expect(mac.rows['project/p1']!.data['name'], 'Браслет');
    expect(mac.outbox, isEmpty, reason: 'входящее не должно уходить обратно');
  });

  test('одновременные правки: побеждает новее, оба устройства получают одно и то же', () async {
    phone.edit(rec('project', 'p', at: 10, device: 'phone', data: <String, Object?>{'name': 'с телефона'}));
    mac.edit(rec('project', 'p', at: 20, device: 'mac', data: <String, Object?>{'name': 'с Mac'}));
    await engineOf(phone).run(userId: 'u');
    final SyncReport macReport = await engineOf(mac).run(userId: 'u');
    expect(macReport.pushed, 1);
    await engineOf(phone).run(userId: 'u');

    expect(phone.rows['project/p']!.data['name'], 'с Mac');
    expect(mac.rows['project/p']!.data['name'], 'с Mac');
  });

  test('сервер отвергает устаревшую отправку, свежая версия приезжает следующим pull', () async {
    phone.edit(rec('project', 'p', at: 10, data: <String, Object?>{'name': 'старое'}));
    mac.edit(rec('project', 'p', at: 20, data: <String, Object?>{'name': 'новое'}));
    await engineOf(mac).run(userId: 'u');
    // Телефон тянет новое до отправки, но его правка уже старее: ничего лишнего не уходит.
    final SyncReport r = await engineOf(phone).run(userId: 'u');
    expect(r.applied, 1);
    expect(phone.rows['project/p']!.data['name'], 'новое');
  });

  test('ребёнок приходит раньше родителя в другой порции: применяется в порядке родитель → ребёнок', () async {
    remote.pageSize = 1;
    // Сначала в базе сервера ребёнок (меньший seq), потом родитель.
    await remote.push(<SyncRecord>[
      rec('grid_pattern', 'p', at: 5, data: <String, Object?>{'w': 3}),
    ]);
    await remote.push(<SyncRecord>[
      rec('project', 'p', at: 6, data: <String, Object?>{'name': 'x'}),
    ]);

    final SyncReport r = await engineOf(mac).run(userId: 'u');
    expect(r.applied, 2);
    expect(mac.rows.keys, containsAll(<String>['project/p', 'grid_pattern/p']));
  });

  test('удаление проекта побеждает: ребёнок не показывается, а при оживлении родителя появляется', () async {
    await remote.push(<SyncRecord>[
      rec('project', 'p', at: 10, deleted: true),
      rec('grid_pattern', 'p', at: 20, data: <String, Object?>{'w': 3}),
    ]);
    final SyncReport r = await engineOf(mac).run(userId: 'u');
    expect(r.held, 1);
    expect(mac.rows.containsKey('grid_pattern/p'), isFalse);
    expect(mac.shadow.containsKey('grid_pattern/p'), isTrue, reason: 'ребёнок не уничтожен');

    await remote.push(<SyncRecord>[
      rec('project', 'p', at: 30, data: <String, Object?>{'name': 'снова'}),
    ]);
    await engineOf(mac).run(userId: 'u');
    expect(mac.rows['project/p']!.isDeleted, isFalse);
    expect(mac.rows['grid_pattern/p']!.data['w'], 3);
    expect(mac.shadow, isEmpty);
  });

  test(
    'формат новее, чем понимает приложение: запись не применяется, курсор идёт дальше, после обновления применяется',
    () async {
      await remote.push(<SyncRecord>[
        rec('project', 'p', at: 10, data: <String, Object?>{'v': 2, 'name': 'новый формат'}),
      ]);

      final SyncReport old = await engineOf(mac).run(userId: 'u');
      expect(old.outdatedFormat, 1);
      expect(old.needsAppUpdate, isTrue);
      expect(mac.rows, isEmpty);
      expect(mac.cursor, greaterThan(0));

      final SyncReport updated = await engineOf(mac, projectVersion: 2).run(userId: 'u');
      expect(updated.cursorReset, isTrue);
      expect(updated.applied, 1);
      expect(mac.rows['project/p']!.data['name'], 'новый формат');
    },
  );

  test('обрыв сети посреди отправки: повтор доставляет остаток, дубликатов нет', () async {
    for (final String id in <String>['a', 'b', 'c']) {
      phone.edit(rec('project', id, at: 10, data: <String, Object?>{'name': id}));
    }
    remote.failOnPushCall = 2;
    await expectLater(engineOf(phone).run(userId: 'u'), throwsStateError);
    expect(phone.outbox, hasLength(1), reason: 'первая порция из двух записей подтверждена');

    remote.failOnPushCall = null;
    await engineOf(phone).run(userId: 'u');
    expect(phone.outbox, isEmpty);
    expect(remote.rows, hasLength(3));
  });

  test('правка во время цикла не теряется: запись, изменённая после чтения, остаётся в очереди', () async {
    phone.edit(rec('project', 'p', at: 10, data: <String, Object?>{'name': '1'}));
    final batch = await phone.pendingOutbox(10);
    phone.edit(rec('project', 'p', at: 11, data: <String, Object?>{'name': '2'}));
    await phone.acknowledge(batch);
    expect(phone.outbox['project/p']!.updatedAt, 11);
  });

  test('чужой аккаунт: синхронизация не стартует и данные не смешиваются', () async {
    await engineOf(phone).run(userId: 'nastya');
    expect(phone.owner, 'nastya');
    await expectLater(engineOf(phone).run(userId: 'other'), throwsA(isA<SyncOwnerMismatch>()));
  });

  test('первый вход: локальные данные и серверные сливаются, ничего не удаляется', () async {
    phone.edit(rec('project', 'local', at: 10, data: <String, Object?>{'name': 'local'}));
    await remote.push(<SyncRecord>[
      rec('project', 'cloud', at: 5, data: <String, Object?>{'name': 'cloud'}),
    ]);
    await engineOf(phone).run(userId: 'u');
    expect(phone.rows.keys, containsAll(<String>['project/local', 'project/cloud']));
    expect(remote.rows.keys, containsAll(<String>['project/local', 'project/cloud']));
  });

  test('FK: ребёнок без родителя валит транзакцию и курсор не двигается', () async {
    await remote.push(<SyncRecord>[
      rec('progress_row', 'p:1', at: 5, data: <String, Object?>{'pattern': 'nope'}),
    ]);
    await expectLater(engineOf(mac).run(userId: 'u'), throwsStateError);
    expect(mac.cursor, 0);
    expect(mac.rows, isEmpty);
  });
}
