import 'package:beading/data/sync/blob_externalizer.dart';
import 'package:beading/data/sync/record_transport.dart';
import 'package:beading/domain/sync/sync_record.dart';
import 'package:beading/domain/sync/sync_remote.dart';

/// Транспорт синхронизации через Supabase (ADR-0006): таблица `sync_records` + закрытый бакет файлов.
///
/// Слияния здесь нет: сервер только хранит записи (LWW держит триггер) и отдаёт их по курсору `server_seq`.
class SupabaseSyncRemote implements SyncRemote {
  SupabaseSyncRemote({required this.records, required this.externalizer});

  final RecordTransport records;
  final BlobExternalizer externalizer;

  @override
  Future<SyncPage> pullSince(int cursor, {int limit = 500}) async {
    final List<WireRow> rows = await records.select(cursor: cursor, limit: limit);
    final List<SyncRecord> out = <SyncRecord>[];
    for (final WireRow row in rows) {
      out.add(await externalizer.internalize(_toRecord(row)));
    }
    return SyncPage(
      records: out,
      cursor: rows.isEmpty ? cursor : (rows.last['server_seq']! as num).toInt(),
      hasMore: rows.length >= limit,
    );
  }

  @override
  Future<List<PushResult>> push(List<SyncRecord> batch) async {
    final List<WireRow> rows = <WireRow>[];
    for (final SyncRecord r in batch) {
      rows.add(_toRow(await externalizer.externalize(r)));
    }
    final List<WireRow> accepted = await records.upsert(rows);
    final Set<String> acceptedKeys = <String>{for (final WireRow a in accepted) '${a['entity']}/${a['sync_id']}'};
    return <PushResult>[
      for (final SyncRecord r in batch) PushResult(key: r.key, accepted: acceptedKeys.contains(r.key)),
    ];
  }

  SyncRecord _toRecord(WireRow row) => SyncRecord(
    entity: row['entity']! as String,
    syncId: row['sync_id']! as String,
    updatedAt: (row['updated_at']! as num).toInt(),
    deletedAt: (row['deleted_at'] as num?)?.toInt(),
    deviceId: row['device_id']! as String,
    data: ((row['data'] as Map<Object?, Object?>?) ?? const <Object?, Object?>{}).cast<String, Object?>(),
  );

  WireRow _toRow(SyncRecord r) => <String, Object?>{
    'entity': r.entity,
    'sync_id': r.syncId,
    'updated_at': r.updatedAt,
    'deleted_at': r.deletedAt,
    'device_id': r.deviceId,
    'data': r.isDeleted ? <String, Object?>{} : r.data,
  };
}
