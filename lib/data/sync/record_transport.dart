import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Строка таблицы `sync_records` как её отдаёт и принимает сервер.
typedef WireRow = Map<String, Object?>;

/// Тонкая обёртка над таблицей `sync_records` (ADR-0006). Подменяется в тестах.
abstract interface class RecordTransport {
  /// Строки с `server_seq > cursor` по возрастанию, не больше [limit].
  Future<List<WireRow>> select({required int cursor, required int limit});

  /// Upsert строк; возвращает только те, что сервер принял (устаревшие триггер пропускает молча).
  Future<List<WireRow>> upsert(List<WireRow> rows);
}

/// Закрытый бакет `blobs`: путь начинается с `{user_id}/`. Объекты неизменяемые.
abstract interface class BlobTransport {
  /// Загружает объект; уже существующий (то же имя = тот же хеш) — не ошибка.
  Future<void> upload(String path, Uint8List bytes);

  Future<Uint8List> download(String path);

  /// `true`, если объект уже лежит в бакете.
  Future<bool> exists(String path);

  /// Идентификатор вошедшего пользователя (первая папка пути).
  String get userId;
}

class SupabaseRecordTransport implements RecordTransport {
  SupabaseRecordTransport(this._client);

  final SupabaseClient _client;

  static const String _table = 'sync_records';
  static const String _columns = 'entity, sync_id, updated_at, deleted_at, device_id, data, server_seq';

  @override
  Future<List<WireRow>> select({required int cursor, required int limit}) async {
    final List<Map<String, dynamic>> rows = await _client
        .from(_table)
        .select(_columns)
        .gt('server_seq', cursor)
        .order('server_seq')
        .limit(limit);
    return <WireRow>[for (final Map<String, dynamic> r in rows) r.cast<String, Object?>()];
  }

  @override
  Future<List<WireRow>> upsert(List<WireRow> rows) async {
    if (rows.isEmpty) {
      return const <WireRow>[];
    }
    final List<Map<String, dynamic>> accepted = await _client
        .from(_table)
        .upsert(rows, onConflict: 'user_id,entity,sync_id')
        .select('entity, sync_id, server_seq');
    return <WireRow>[for (final Map<String, dynamic> r in accepted) r.cast<String, Object?>()];
  }
}

class SupabaseBlobTransport implements BlobTransport {
  SupabaseBlobTransport(this._client);

  final SupabaseClient _client;

  static const String _bucket = 'blobs';

  @override
  String get userId => _client.auth.currentUser!.id;

  @override
  Future<void> upload(String path, Uint8List bytes) async {
    try {
      await _client.storage.from(_bucket).uploadBinary(path, bytes);
    } on StorageException catch (error) {
      if (error.statusCode != '409' && error.message != 'The resource already exists') {
        rethrow;
      }
    }
  }

  @override
  Future<Uint8List> download(String path) => _client.storage.from(_bucket).download(path);

  @override
  Future<bool> exists(String path) => _client.storage.from(_bucket).exists(path);
}
