import 'package:beading/domain/sync/sync_record.dart';

/// Чистые правила слияния записей (ADR-0006). Без побочных эффектов.
abstract final class MergePolicy {
  /// `true`, если [a] новее [b]: сравнение по `(updatedAt, deviceId)`.
  static bool isNewer(SyncRecord a, SyncRecord b) {
    if (a.updatedAt != b.updatedAt) {
      return a.updatedAt > b.updatedAt;
    }
    return a.deviceId.compareTo(b.deviceId) > 0;
  }

  /// Какую запись оставить: новее выигрывает (в том числе надгробие над правкой и наоборот).
  /// Одинаковые записи возвращают [local].
  static SyncRecord resolve(SyncRecord? local, SyncRecord remote) {
    if (local == null) {
      return remote;
    }
    return isNewer(remote, local) ? remote : local;
  }

  /// `updated_at` при правке существующей записи: правка всегда новее версии, поверх которой сделана,
  /// независимо от часов устройства. Для новой записи [previous] равен `null`.
  static int nextUpdatedAt({required int now, int? previous}) {
    if (previous == null || now > previous) {
      return now;
    }
    return previous + 1;
  }
}
