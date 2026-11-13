import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/sync/sync_entity_mapper.dart';
import 'package:beading/data/sync/sync_entity_mappers.dart';
import 'package:beading/domain/sync/merge_policy.dart';
import 'package:beading/domain/sync/sync_entities.dart';
import 'package:beading/domain/sync/sync_record.dart';
import 'package:beading/domain/sync/sync_store.dart';

/// Локальная сторона синхронизации на drift (ADR-0006): очередь `sync_outbox`, теневая копия `sync_shadow`,
/// владелец, курсор и отпечаток версий в настройках с префиксом `local.`.
class DriftSyncStore implements SyncStore {
  DriftSyncStore({required this.ctx})
    : _mappers = <String, SyncEntityMapper>{for (final SyncEntityMapper m in buildSyncMappers(ctx)) m.entity: m};

  final SyncDbContext ctx;
  final Map<String, SyncEntityMapper> _mappers;

  AppDatabase get _db => ctx.db;

  /// Описание сущностей для [SyncEngine]: порядок применения, версии формата, родители.
  SyncSchema get schema => SyncSchema(<SyncEntitySpec>[
    for (final SyncEntityMapper m in _mappers.values)
      SyncEntitySpec(name: m.entity, rank: m.rank, supportedVersion: m.supportedVersion, parentOf: m.parentKey),
  ]);

  static const String _ownerKey = 'local.sync.userId';
  static const String _cursorKey = 'local.sync.cursor';
  static const String _fingerprintKey = 'local.sync.fingerprint';

  Future<String?> _getLocal(String key) async =>
      (await ctx.first('SELECT value FROM settings WHERE "key" = ?', <Object?>[key]))?['value'] as String?;

  Future<void> _setLocal(String key, String value) => ctx.run(
    'INSERT INTO settings ("key", value, created_at, updated_at, device_id) VALUES (?,?,0,0,\'local\') '
    'ON CONFLICT("key") DO UPDATE SET value = excluded.value',
    <Object?>[key, value],
  );

  @override
  Future<String?> readOwner() => _getLocal(_ownerKey);

  /// Первая привязка к аккаунту: всё, что уже есть на устройстве, ставится в очередь на отправку.
  @override
  Future<void> writeOwner(String userId) => _db.transaction(() async {
    await _setLocal(_ownerKey, userId);
    for (final SyncEntityMapper m in _mappers.values) {
      for (final String id in await m.allSyncIds()) {
        await ctx.run('INSERT INTO sync_outbox (entity, sync_id) VALUES (?, ?) ON CONFLICT DO NOTHING', <Object?>[
          m.entity,
          id,
        ]);
      }
    }
  });

  @override
  Future<int> readCursor() async => int.tryParse(await _getLocal(_cursorKey) ?? '') ?? 0;

  @override
  Future<String?> readFingerprint() => _getLocal(_fingerprintKey);

  @override
  Future<void> resetCursor(String fingerprint) => _db.transaction(() async {
    await _setLocal(_cursorKey, '0');
    await _setLocal(_fingerprintKey, fingerprint);
  });

  Future<SyncRecord?> _shadow(String entity, String syncId) async {
    final Row? r = await ctx.first('SELECT * FROM sync_shadow WHERE entity = ? AND sync_id = ?', <Object?>[
      entity,
      syncId,
    ]);
    return r == null ? null : _shadowRecord(r);
  }

  SyncRecord _shadowRecord(Row r) => SyncRecord(
    entity: r['entity']! as String,
    syncId: r['sync_id']! as String,
    updatedAt: r['updated_at']! as int,
    deletedAt: r['deleted_at'] as int?,
    deviceId: r['device_id']! as String,
    data: decodeData(r['data']! as String),
  );

  @override
  Future<SyncRecord?> find(String entity, String syncId) async {
    final SyncEntityMapper? mapper = _mappers[entity];
    if (mapper == null) {
      return null;
    }
    final SyncRecord? local = await mapper.read(syncId);
    final SyncRecord? shadow = await _shadow(entity, syncId);
    if (local == null || shadow == null) {
      return local ?? shadow;
    }
    return MergePolicy.isNewer(shadow, local) ? shadow : local;
  }

  @override
  Future<List<SyncRecord>> pendingOutbox(int limit) async {
    final List<Row> queued = await ctx.query('SELECT entity, sync_id FROM sync_outbox ORDER BY rowid');
    final List<SyncRecord> out = <SyncRecord>[];
    for (final Row q in queued) {
      if (out.length >= limit) {
        break;
      }
      final String entity = q['entity']! as String;
      final String syncId = q['sync_id']! as String;
      final SyncEntityMapper? mapper = _mappers[entity];
      final SyncRecord? current = await mapper?.read(syncId);
      if (mapper == null || current == null) {
        await ctx.run('DELETE FROM sync_outbox WHERE entity = ? AND sync_id = ?', <Object?>[entity, syncId]);
        continue;
      }
      final Row? shadowRow = await ctx.first('SELECT * FROM sync_shadow WHERE entity = ? AND sync_id = ?', <Object?>[
        entity,
        syncId,
      ]);
      final SyncRecord? shadow = shadowRow == null ? null : _shadowRecord(shadowRow);
      if (shadow != null && shadow.version > mapper.supportedVersion) {
        continue; // запись новее формата этого приложения: не перезаписываем (R-13)
      }
      // Поля, которых эта версия приложения не знает, берём из теневой копии (R-13).
      final Map<String, Object?> data = current.isDeleted || shadow == null || shadow.isDeleted
          ? current.data
          : <String, Object?>{...shadow.data, ...current.data};
      out.add(
        SyncRecord(
          entity: entity,
          syncId: syncId,
          updatedAt: current.updatedAt,
          deletedAt: current.deletedAt,
          deviceId: current.deviceId,
          data: data,
        ),
      );
    }
    return out;
  }

  @override
  Future<void> applyIncoming({
    required List<SyncRecord> records,
    required List<SyncRecord> held,
    required int cursor,
  }) => _db.transaction(() async {
    await ctx.run('INSERT OR IGNORE INTO sync_applying (flag) VALUES (1)');
    for (final SyncRecord r in records) {
      await _mappers[r.entity]!.apply(r);
      await _putShadow(r, held: false);
    }
    for (final SyncRecord h in held) {
      await _putShadow(h, held: true);
    }
    await ctx.run('DELETE FROM sync_applying');
    await _setLocal(_cursorKey, '$cursor');
  });

  Future<void> _putShadow(SyncRecord r, {required bool held}) => ctx.run(
    'INSERT INTO sync_shadow (entity, sync_id, updated_at, deleted_at, device_id, data, held) VALUES (?,?,?,?,?,?,?) '
    'ON CONFLICT(entity, sync_id) DO UPDATE SET updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, '
    'device_id=excluded.device_id, data=excluded.data, held=excluded.held',
    <Object?>[r.entity, r.syncId, r.updatedAt, r.deletedAt, r.deviceId, encodeData(r.data), if (held) 1 else 0],
  );

  @override
  Future<List<SyncRecord>> heldChildrenOf(String parentKey) async {
    final List<Row> rows = await ctx.query('SELECT * FROM sync_shadow WHERE held = 1');
    final List<SyncRecord> out = <SyncRecord>[];
    for (final Row row in rows) {
      final SyncRecord r = _shadowRecord(row);
      final SyncEntityMapper? m = _mappers[r.entity];
      if (m != null && !r.isDeleted && r.version <= m.supportedVersion && m.parentKey(r) == parentKey) {
        out.add(r);
      }
    }
    return out;
  }

  @override
  Future<void> acknowledge(List<SyncRecord> pushed) => _db.transaction(() async {
    for (final SyncRecord p in pushed) {
      final SyncRecord? current = await _mappers[p.entity]?.read(p.syncId);
      if (current == null ||
          (current.updatedAt == p.updatedAt && current.deviceId == p.deviceId && current.deletedAt == p.deletedAt)) {
        await ctx.run('DELETE FROM sync_outbox WHERE entity = ? AND sync_id = ?', <Object?>[p.entity, p.syncId]);
      }
    }
  });
}
