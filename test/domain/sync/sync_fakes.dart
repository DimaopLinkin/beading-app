import 'package:beading/domain/sync/merge_policy.dart';
import 'package:beading/domain/sync/sync_entities.dart';
import 'package:beading/domain/sync/sync_record.dart';
import 'package:beading/domain/sync/sync_remote.dart';
import 'package:beading/domain/sync/sync_store.dart';

/// Схема для тестов: project → grid_pattern → progress_row (дети обязаны приходить после родителей).
SyncSchema testSchema({int projectVersion = 1}) => SyncSchema(<SyncEntitySpec>[
  SyncEntitySpec(name: 'project', rank: 0, supportedVersion: projectVersion),
  SyncEntitySpec(name: 'grid_pattern', rank: 1, parentOf: (r) => 'project/${r.syncId}'),
  SyncEntitySpec(
    name: 'progress_row',
    rank: 2,
    parentOf: (r) => 'grid_pattern/${r.data['pattern']}',
  ),
]);

SyncRecord rec(
  String entity,
  String syncId, {
  required int at,
  String device = 'A',
  bool deleted = false,
  Map<String, Object?> data = const <String, Object?>{},
}) => SyncRecord(
  entity: entity,
  syncId: syncId,
  updatedAt: at,
  deletedAt: deleted ? at : null,
  deviceId: device,
  data: deleted ? const <String, Object?>{} : data,
);

/// Сервер с поведением серверного триггера: старая запись не затирает новую, `server_seq` растёт.
class FakeRemote implements SyncRemote {
  final Map<String, SyncRecord> rows = <String, SyncRecord>{};
  final Map<String, int> seqOf = <String, int>{};
  int _seq = 0;
  int pushCalls = 0;

  /// Бросает исключение на этой по счёту отправке (обрыв сети), если задано.
  int? failOnPushCall;

  /// Если задано, порции pull возвращаются в порядке seq, но по [pageSize] штук.
  int? pageSize;

  @override
  Future<SyncPage> pullSince(int cursor, {int limit = 500}) async {
    final int size = pageSize ?? limit;
    final List<MapEntry<String, SyncRecord>> after = rows.entries.where((e) => seqOf[e.key]! > cursor).toList()
      ..sort(
        (a, b) => seqOf[a.key]!.compareTo(seqOf[b.key]!),
      );
    final List<MapEntry<String, SyncRecord>> page = after.take(size).toList();
    return SyncPage(
      records: page.map((e) => e.value).toList(),
      cursor: page.isEmpty ? cursor : seqOf[page.last.key]!,
      hasMore: after.length > page.length,
    );
  }

  @override
  Future<List<PushResult>> push(List<SyncRecord> records) async {
    pushCalls++;
    if (failOnPushCall == pushCalls) {
      throw StateError('network down');
    }
    final List<PushResult> out = <PushResult>[];
    for (final SyncRecord r in records) {
      final SyncRecord? old = rows[r.key];
      final bool wins = old == null || MergePolicy.isNewer(r, old);
      if (wins) {
        rows[r.key] = r;
        seqOf[r.key] = ++_seq;
      }
      out.add(PushResult(key: r.key, accepted: wins));
    }
    return out;
  }
}

/// Локальная база: проверяет «внешний ключ» (ребёнок без родителя при применении = ошибка), как drift с foreign_keys = ON.
class FakeStore implements SyncStore {
  FakeStore();

  final Map<String, SyncRecord> rows = <String, SyncRecord>{};
  final Map<String, SyncRecord> shadow = <String, SyncRecord>{};
  final Map<String, SyncRecord> outbox = <String, SyncRecord>{};
  String? owner;
  int cursor = 0;
  String? fingerprint;
  final SyncSchema schema = testSchema();

  /// Локальная правка: попадает в базу и в очередь.
  void edit(SyncRecord r) {
    rows[r.key] = r;
    outbox[r.key] = r;
  }

  @override
  Future<String?> readOwner() async => owner;

  @override
  Future<void> writeOwner(String userId) async => owner = userId;

  @override
  Future<int> readCursor() async => cursor;

  @override
  Future<String?> readFingerprint() async => fingerprint;

  @override
  Future<void> resetCursor(String fingerprint) async {
    cursor = 0;
    this.fingerprint = fingerprint;
  }

  @override
  Future<SyncRecord?> find(String entity, String syncId) async => rows['$entity/$syncId'];

  @override
  Future<List<SyncRecord>> pendingOutbox(int limit) async => outbox.values.take(limit).toList();

  @override
  Future<void> applyIncoming({
    required List<SyncRecord> records,
    required List<SyncRecord> held,
    required int cursor,
  }) async {
    final Map<String, SyncRecord> snapshot = Map<String, SyncRecord>.of(rows);
    for (final SyncRecord r in records) {
      final String? parent = schema.specOf(r.entity)!.parentOf?.call(r);
      if (parent != null && !r.isDeleted && rows[parent] == null) {
        rows
          ..clear()
          ..addAll(snapshot);
        throw StateError('FOREIGN KEY constraint failed: ${r.key} без родителя $parent');
      }
      rows[r.key] = r; // входящие записи в очередь не попадают (триггеры глушатся)
    }
    for (final SyncRecord h in held) {
      shadow[h.key] = h;
    }
    for (final SyncRecord r in records) {
      shadow.remove(r.key);
    }
    this.cursor = cursor;
  }

  @override
  Future<List<SyncRecord>> heldChildrenOf(String parentKey) async => shadow.values.where((r) {
    final SyncEntitySpec? spec = schema.specOf(r.entity);
    return spec?.parentOf?.call(r) == parentKey && r.version <= spec!.supportedVersion;
  }).toList();

  @override
  Future<void> acknowledge(List<SyncRecord> pushed) async {
    for (final SyncRecord r in pushed) {
      if (outbox[r.key] == r) {
        outbox.remove(r.key);
      }
    }
  }
}
