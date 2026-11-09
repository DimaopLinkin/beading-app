import 'package:beading/core/clock.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/settings_dao.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:beading/domain/settings/setting_key.dart';

/// Хранит идентификатор устройства в `settings` под ключом `local.deviceId`.
class DriftDeviceIdProvider implements DeviceIdProvider {
  DriftDeviceIdProvider({required SettingsDao dao, required IdGenerator ids, required Clock clock})
    : _dao = dao,
      _ids = ids,
      _clock = clock;

  /// Префикс `local.`: такие ключи не синхронизируются.
  static const String storageKey = '${SettingKey.localPrefix}deviceId';

  final SettingsDao _dao;
  final IdGenerator _ids;
  final Clock _clock;

  Future<Result<String>>? _pending;
  String? _cached;

  @override
  Future<Result<String>> deviceId() async {
    final String? cached = _cached;
    if (cached != null) {
      return Success<String>(cached);
    }
    // Параллельные вызовы ждут один и тот же запрос и не создают два идентификатора.
    final Future<Result<String>> pending = _pending ??= _loadOrCreate();
    final Result<String> result = await pending;
    _pending = null;
    if (result case Success<String>(:final String value)) {
      _cached = value;
    }
    return result;
  }

  Future<Result<String>> _loadOrCreate() => guardStorage<String>(() async {
    final SettingRow? row = await _dao.find(storageKey);
    if (row != null && row.deletedAt == null && row.value.isNotEmpty) {
      return row.value;
    }
    final String id = _ids.next();
    await _dao.upsert(key: storageKey, value: id, nowMs: _clock.now().millisecondsSinceEpoch, deviceId: id);
    return id;
  });
}
