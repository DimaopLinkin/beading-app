import 'package:beading/domain/sync/sync_record.dart';

/// Порция записей сервера после курсора.
class SyncPage {
  const SyncPage({required this.records, required this.cursor, required this.hasMore});

  final List<SyncRecord> records;

  /// Курсор, с которого продолжать (последний `server_seq` порции).
  final int cursor;

  final bool hasMore;
}

/// Результат отправки одной записи: сервер мог отвергнуть устаревшую.
class PushResult {
  const PushResult({required this.key, required this.accepted});

  final String key;
  final bool accepted;
}

/// Транспорт: сервер хранит записи и отдаёт их по курсору. Слияние сюда не входит.
abstract interface class SyncRemote {
  Future<SyncPage> pullSince(int cursor, {int limit = 500});

  Future<List<PushResult>> push(List<SyncRecord> records);
}
