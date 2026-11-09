import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/in_memory_database.dart';

class _SequenceIds implements IdGenerator {
  int _next = 0;

  @override
  String next() => 'id-${_next++}';
}

void main() {
  late AppDatabase database;
  late FakeClock clock;
  late _SequenceIds ids;

  DriftDeviceIdProvider createProvider() => DriftDeviceIdProvider(dao: database.settingsDao, ids: ids, clock: clock);

  setUp(() {
    database = createInMemoryDatabase();
    clock = FakeClock(DateTime.utc(2026, 11, 9, 12));
    ids = _SequenceIds();
  });

  test('первый вызов создаёт идентификатор и сохраняет его в settings', () async {
    final Result<String> result = await createProvider().deviceId();

    expect(result, const Success<String>('id-0'));
    final row = await database.settingsDao.find(DriftDeviceIdProvider.storageKey);
    expect(row?.value, 'id-0');
    expect(row?.deviceId, 'id-0');
    expect(row?.createdAt, clock.now().millisecondsSinceEpoch);
  });

  test('повторные вызовы и новый провайдер на той же базе возвращают тот же идентификатор', () async {
    final DriftDeviceIdProvider first = createProvider();

    expect(await first.deviceId(), const Success<String>('id-0'));
    expect(await first.deviceId(), const Success<String>('id-0'));
    expect(await createProvider().deviceId(), const Success<String>('id-0'));
  });

  test('параллельные вызовы не создают два идентификатора', () async {
    final DriftDeviceIdProvider provider = createProvider();

    final List<Result<String>> results = await Future.wait(<Future<Result<String>>>[
      provider.deviceId(),
      provider.deviceId(),
      provider.deviceId(),
    ]);

    expect(results, everyElement(const Success<String>('id-0')));
  });

  test('удалённая запись заменяется новым идентификатором', () async {
    await createProvider().deviceId();
    await database.settingsDao.tombstone(key: DriftDeviceIdProvider.storageKey, nowMs: 1, deviceId: 'x');

    expect(await createProvider().deviceId(), const Success<String>('id-1'));
  });

  test('ошибка хранилища возвращается как Failure, а не исключением', () async {
    final DriftDeviceIdProvider provider = createProvider();
    await database.customStatement('DROP TABLE settings');

    final Result<String> result = await provider.deviceId();

    expect(result.isFailure, isTrue);
  });
}
