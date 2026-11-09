import 'package:beading/core/result.dart';

/// Идентификатор этого устройства для служебного поля `device_id`.
///
/// Создаётся один раз при первом обращении, дальше не меняется. Не синхронизируется (ключ `local.deviceId`).
abstract interface class DeviceIdProvider {
  Future<Result<String>> deviceId();
}
