import 'package:beading/domain/sync/sync_record.dart';

/// Локальная сторона синхронизации: база приложения, очередь изменений, курсор.
abstract interface class SyncStore {
  /// Аккаунт, чьи данные лежат в базе, или `null`, если синхронизация ещё не включалась.
  Future<String?> readOwner();

  Future<void> writeOwner(String userId);

  Future<int> readCursor();

  /// Отпечаток версий, с которым работал прошлый цикл (см. [SyncSchema.fingerprint]).
  Future<String?> readFingerprint();

  /// Сбрасывает курсор в 0 и запоминает новый [fingerprint].
  Future<void> resetCursor(String fingerprint);

  /// Текущее состояние записи (с учётом надгробия) или `null`, если записи нет.
  Future<SyncRecord?> find(String entity, String syncId);

  /// Записи очереди изменений, не более [limit].
  Future<List<SyncRecord>> pendingOutbox(int limit);

  /// Применяет принятые записи и новый [cursor] одной транзакцией; порядок записей уже «родители → дети».
  /// [held] — записи, чей родитель удалён: сохраняются только в «теневой» копии и живыми не показываются.
  Future<void> applyIncoming({required List<SyncRecord> records, required List<SyncRecord> held, required int cursor});

  /// Записи, которые ждали родителя [parentKey] (`entity/syncId`).
  Future<List<SyncRecord>> heldChildrenOf(String parentKey);

  /// Убирает из очереди ровно те записи, которые не менялись после чтения.
  Future<void> acknowledge(List<SyncRecord> pushed);
}
