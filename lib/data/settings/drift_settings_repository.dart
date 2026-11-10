import 'package:beading/core/clock.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/settings_dao.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:beading/domain/settings/setting_key.dart';
import 'package:beading/domain/settings/settings_repository.dart';

/// Настройки в таблице `settings`. Сам ставит `updated_at` и `device_id`.
class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository({required SettingsDao dao, required DeviceIdProvider deviceIds, required Clock clock})
    : _dao = dao,
      _deviceIds = deviceIds,
      _clock = clock;

  final SettingsDao _dao;
  final DeviceIdProvider _deviceIds;
  final Clock _clock;

  @override
  Future<Result<T>> read<T>(SettingKey<T> key) => guardStorage<T>(() async => _valueOf(key, await _dao.find(key.name)));

  @override
  Future<Result<void>> write<T>(SettingKey<T> key, T value) => _withDeviceId(
    (deviceId) => _dao.upsert(key: key.name, value: key.encode(value), nowMs: _nowMs(), deviceId: deviceId),
  );

  @override
  Future<Result<void>> reset<T>(SettingKey<T> key) =>
      _withDeviceId((deviceId) => _dao.tombstone(key: key.name, nowMs: _nowMs(), deviceId: deviceId));

  @override
  Stream<T> watch<T>(SettingKey<T> key) => _dao.watch(key.name).map((row) => _valueOf(key, row));

  int _nowMs() => _clock.now().millisecondsSinceEpoch;

  T _valueOf<T>(SettingKey<T> key, SettingRow? row) {
    if (row == null || row.deletedAt != null) {
      return key.defaultValue;
    }
    return key.decode(row.value) ?? key.defaultValue;
  }

  Future<Result<void>> _withDeviceId(Future<void> Function(String deviceId) action) async {
    final Result<String> id = await _deviceIds.deviceId();
    return switch (id) {
      Err<String>(:final failure) => Err<void>(failure),
      Success<String>(:final String value) => guardStorage<void>(() => action(value)),
    };
  }
}
