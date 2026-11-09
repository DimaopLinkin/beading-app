import 'package:async/async.dart' show StreamQueue;
import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/data/settings/drift_settings_repository.dart';
import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:beading/domain/settings/setting_key.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/special_date.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/in_memory_database.dart';

class _FixedDeviceId implements DeviceIdProvider {
  _FixedDeviceId(this.value);

  String value;

  @override
  Future<Result<String>> deviceId() async => Success<String>(value);
}

void main() {
  late AppDatabase database;
  late FakeClock clock;
  late _FixedDeviceId deviceId;
  late DriftSettingsRepository repository;

  setUp(() {
    database = createInMemoryDatabase();
    clock = FakeClock(DateTime.utc(2026, 11, 9, 12));
    deviceId = _FixedDeviceId('device-a');
    repository = DriftSettingsRepository(dao: database.settingsDao, deviceIds: deviceId, clock: clock);
  });

  Future<T> read<T>(SettingKey<T> key) async => (await repository.read(key)).valueOrNull as T;

  group('чтение', () {
    test('без записи возвращает значение по умолчанию для каждого ключа', () async {
      expect(await read(SettingKeys.themeMode), AppThemeMode.system);
      expect(await read(SettingKeys.keepScreenAwake), isTrue);
      expect(await read(SettingKeys.symbolMode), isFalse);
      expect(await read(SettingKeys.defaultBeadBrand), 'Miyuki');
      expect(await read(SettingKeys.defaultFlossBrand), 'DMC');
      expect(await read(SettingKeys.userName), 'Настя');
      expect(await read(SettingKeys.specialDates), isEmpty);
    });

    test('повреждённое значение в базе даёт значение по умолчанию', () async {
      await database.settingsDao.upsert(key: 'themeMode', value: 'neon', nowMs: 1, deviceId: 'x');

      expect(await read(SettingKeys.themeMode), AppThemeMode.system);
    });
  });

  group('запись', () {
    test('сохраняет и читает каждый ключ', () async {
      const List<SpecialDate> dates = <SpecialDate>[SpecialDate(label: 'День рождения', month: 3, day: 14)];

      await repository.write(SettingKeys.themeMode, AppThemeMode.dark);
      await repository.write(SettingKeys.keepScreenAwake, false);
      await repository.write(SettingKeys.symbolMode, true);
      await repository.write(SettingKeys.defaultBeadBrand, 'Toho');
      await repository.write(SettingKeys.defaultFlossBrand, 'Anchor');
      await repository.write(SettingKeys.userName, 'Анастасия');
      await repository.write(SettingKeys.specialDates, dates);

      expect(await read(SettingKeys.themeMode), AppThemeMode.dark);
      expect(await read(SettingKeys.keepScreenAwake), isFalse);
      expect(await read(SettingKeys.symbolMode), isTrue);
      expect(await read(SettingKeys.defaultBeadBrand), 'Toho');
      expect(await read(SettingKeys.defaultFlossBrand), 'Anchor');
      expect(await read(SettingKeys.userName), 'Анастасия');
      expect(await read(SettingKeys.specialDates), dates);
    });

    test('бренд бисера и бренд мулине хранятся независимо', () async {
      await repository.write(SettingKeys.defaultBeadBrand, 'Preciosa');

      expect(await read(SettingKeys.defaultFlossBrand), 'DMC');
    });

    test('ставит created_at, updated_at и device_id', () async {
      await repository.write(SettingKeys.userName, 'Настенька');

      final row = await database.settingsDao.find('userName');
      expect(row?.createdAt, DateTime.utc(2026, 11, 9, 12).millisecondsSinceEpoch);
      expect(row?.updatedAt, row?.createdAt);
      expect(row?.deletedAt, isNull);
      expect(row?.deviceId, 'device-a');
    });

    test('повторная запись обновляет updated_at и device_id, но не created_at', () async {
      await repository.write(SettingKeys.userName, 'Первое');
      final int createdAt = clock.now().millisecondsSinceEpoch;
      clock.advance(const Duration(minutes: 5));
      deviceId.value = 'device-b';

      await repository.write(SettingKeys.userName, 'Второе');

      final row = await database.settingsDao.find('userName');
      expect(row?.value, 'Второе');
      expect(row?.createdAt, createdAt);
      expect(row?.updatedAt, clock.now().millisecondsSinceEpoch);
      expect(row?.deviceId, 'device-b');
      expect(await database.select(database.settings).get(), hasLength(1));
    });

    test('ошибка получения device_id возвращается как Failure и ничего не пишет', () async {
      final DriftSettingsRepository broken = DriftSettingsRepository(
        dao: database.settingsDao,
        deviceIds: _FailingDeviceId(),
        clock: clock,
      );

      final Result<void> result = await broken.write(SettingKeys.userName, 'x');

      expect(result.isFailure, isTrue);
      expect(await database.settingsDao.find('userName'), isNull);
    });

    test('ошибка хранилища возвращается как Failure', () async {
      await database.customStatement('DROP TABLE settings');

      expect((await repository.write(SettingKeys.userName, 'x')).isFailure, isTrue);
      expect((await repository.read(SettingKeys.userName)).isFailure, isTrue);
      expect((await repository.reset(SettingKeys.userName)).isFailure, isTrue);
    });

    test('работает вместе с настоящим DriftDeviceIdProvider', () async {
      final DriftSettingsRepository real = DriftSettingsRepository(
        dao: database.settingsDao,
        deviceIds: DriftDeviceIdProvider(dao: database.settingsDao, ids: _Ids(), clock: clock),
        clock: clock,
      );

      await real.write(SettingKeys.symbolMode, true);

      expect((await database.settingsDao.find('symbolMode'))?.deviceId, 'generated-id');
    });
  });

  group('сброс', () {
    test('возвращает значение по умолчанию и оставляет надгробие', () async {
      await repository.write(SettingKeys.userName, 'Настенька');
      clock.advance(const Duration(minutes: 1));

      await repository.reset(SettingKeys.userName);

      expect(await read(SettingKeys.userName), 'Настя');
      final row = await database.settingsDao.find('userName');
      expect(row?.deletedAt, clock.now().millisecondsSinceEpoch);
      expect(row?.updatedAt, clock.now().millisecondsSinceEpoch);
    });

    test('запись после сброса снимает надгробие', () async {
      await repository.write(SettingKeys.userName, 'Настенька');
      await repository.reset(SettingKeys.userName);

      await repository.write(SettingKeys.userName, 'Снова');

      expect(await read(SettingKeys.userName), 'Снова');
      expect((await database.settingsDao.find('userName'))?.deletedAt, isNull);
    });

    test('сброс незаданной настройки ничего не создаёт', () async {
      final Result<void> result = await repository.reset(SettingKeys.userName);

      expect(result.isSuccess, isTrue);
      expect(await database.settingsDao.find('userName'), isNull);
    });

    test('повторный сброс не двигает updated_at', () async {
      await repository.write(SettingKeys.userName, 'x');
      await repository.reset(SettingKeys.userName);
      final int deletedAt = (await database.settingsDao.find('userName'))!.deletedAt!;
      clock.advance(const Duration(minutes: 1));

      await repository.reset(SettingKeys.userName);

      expect((await database.settingsDao.find('userName'))?.deletedAt, deletedAt);
    });
  });

  group('watch', () {
    test('отдаёт текущее значение и каждое изменение', () async {
      final StreamQueue<AppThemeMode> queue = StreamQueue<AppThemeMode>(repository.watch(SettingKeys.themeMode));
      addTearDown(queue.cancel);

      expect(await queue.next, AppThemeMode.system);
      await repository.write(SettingKeys.themeMode, AppThemeMode.dark);
      expect(await queue.next, AppThemeMode.dark);
      await repository.reset(SettingKeys.themeMode);
      expect(await queue.next, AppThemeMode.system);
    });
  });
}

class _FailingDeviceId implements DeviceIdProvider {
  @override
  Future<Result<String>> deviceId() async => const Err<String>(StorageFailure('нет'));
}

class _Ids implements IdGenerator {
  @override
  String next() => 'generated-id';
}
