import 'package:beading/domain/sync/merge_policy.dart';
import 'package:beading/domain/sync/sync_entities.dart';
import 'package:beading/domain/sync/sync_record.dart';
import 'package:beading/domain/sync/sync_remote.dart';
import 'package:beading/domain/sync/sync_store.dart';

/// В базе лежат данные другого аккаунта: синхронизация не стартует, пока пользователь не выберет, что делать (ADR-0006).
class SyncOwnerMismatch implements Exception {
  const SyncOwnerMismatch({required this.localOwner, required this.requestedOwner});

  final String localOwner;
  final String requestedOwner;

  @override
  String toString() => 'SyncOwnerMismatch(local: $localOwner, requested: $requestedOwner)';
}

/// Итог одного цикла синхронизации.
class SyncReport {
  const SyncReport({
    required this.pulled,
    required this.applied,
    required this.held,
    required this.outdatedFormat,
    required this.pushed,
    required this.rejected,
    required this.cursorReset,
  });

  final int pulled;
  final int applied;

  /// Не показаны: родитель удалён или формат новее, чем понимает это приложение.
  final int held;

  /// Сколько записей пришло в формате новее: пользователю предлагается обновить приложение.
  final int outdatedFormat;

  final int pushed;

  /// Сервер отверг как устаревшие; свежая версия приедет следующим pull.
  final int rejected;

  /// Курсор сброшен после обновления приложения (выросла поддерживаемая версия формата).
  final bool cursorReset;

  bool get needsAppUpdate => outdatedFormat > 0;
}

/// Один цикл: pull до конца → слияние → применение одной транзакцией → push очереди (ADR-0006).
/// Повторный запуск после обрыва безопасен: курсор и очередь двигаются только после успеха шага.
class SyncEngine {
  SyncEngine({
    required this.store,
    required this.remote,
    required this.schema,
    this.pullLimit = 500,
    this.pushBatch = 200,
  });

  final SyncStore store;
  final SyncRemote remote;
  final SyncSchema schema;
  final int pullLimit;
  final int pushBatch;

  Future<SyncReport> run({required String userId}) async {
    final String? owner = await store.readOwner();
    if (owner != null && owner != userId) {
      throw SyncOwnerMismatch(localOwner: owner, requestedOwner: userId);
    }
    if (owner == null) {
      await store.writeOwner(userId);
    }

    bool cursorReset = false;
    final String fingerprint = schema.fingerprint;
    if (await store.readFingerprint() != fingerprint) {
      await store.resetCursor(fingerprint);
      cursorReset = true;
    }

    final int startCursor = await store.readCursor();
    final List<SyncRecord> incoming = <SyncRecord>[];
    int cursor = startCursor;
    while (true) {
      final SyncPage page = await remote.pullSince(cursor, limit: pullLimit);
      incoming.addAll(page.records);
      cursor = page.cursor;
      if (!page.hasMore) {
        break;
      }
    }

    final _Plan plan = await _plan(incoming);
    if (incoming.isNotEmpty || cursor != startCursor) {
      await store.applyIncoming(records: plan.apply, held: plan.held, cursor: cursor);
    }

    int pushed = 0;
    int rejected = 0;
    while (true) {
      final List<SyncRecord> batch = await store.pendingOutbox(pushBatch);
      if (batch.isEmpty) {
        break;
      }
      final List<PushResult> results = await remote.push(batch);
      rejected += results.where((r) => !r.accepted).length;
      pushed += results.where((r) => r.accepted).length;
      await store.acknowledge(batch);
    }

    return SyncReport(
      pulled: incoming.length,
      applied: plan.apply.length,
      held: plan.held.length,
      outdatedFormat: plan.outdated,
      pushed: pushed,
      rejected: rejected,
      cursorReset: cursorReset,
    );
  }

  Future<_Plan> _plan(List<SyncRecord> incoming) async {
    // Оставляем новейшую версию каждого ключа внутри пришедшего.
    final Map<String, SyncRecord> latest = <String, SyncRecord>{};
    for (final SyncRecord r in incoming) {
      latest[r.key] = MergePolicy.resolve(latest[r.key], r);
    }

    final List<SyncRecord> winners = <SyncRecord>[];
    int outdated = 0;
    final List<SyncRecord> held = <SyncRecord>[];
    for (final SyncRecord remote in latest.values) {
      final SyncEntitySpec? spec = schema.specOf(remote.entity);
      if (spec == null) {
        continue; // сущность из более новой версии приложения: сюда не относится
      }
      if (!remote.isDeleted && remote.version > spec.supportedVersion) {
        outdated++;
        held.add(remote);
        continue;
      }
      final SyncRecord? local = await store.find(remote.entity, remote.syncId);
      if (local == null || MergePolicy.isNewer(remote, local)) {
        winners.add(remote);
      }
    }

    winners.sort(
      (a, b) => schema.specOf(a.entity)!.rank.compareTo(schema.specOf(b.entity)!.rank),
    );

    // «Удаление поддерева побеждает»: ребёнок удалённого родителя не показывается и ждёт в held (R-06).
    final Set<String> deleted = <String>{
      for (final SyncRecord r in winners)
        if (r.isDeleted) r.key,
    };
    final List<SyncRecord> apply = <SyncRecord>[];
    for (final SyncRecord r in winners) {
      final String? parentKey = schema.specOf(r.entity)!.parentOf?.call(r);
      if (parentKey != null && !r.isDeleted && await _isDeleted(parentKey, deleted)) {
        held.add(r);
      } else {
        apply.add(r);
      }
    }

    // Родитель ожил (или впервые приехал живым): применяем детей, ждавших его.
    for (final SyncRecord r in List<SyncRecord>.of(apply)) {
      if (r.isDeleted) {
        continue;
      }
      for (final SyncRecord child in await store.heldChildrenOf(r.key)) {
        final bool sameBatch = apply.any((a) => a.key == child.key) || held.any((h) => h.key == child.key);
        if (!sameBatch) {
          apply.add(child);
        }
      }
    }
    apply.sort((a, b) => schema.specOf(a.entity)!.rank.compareTo(schema.specOf(b.entity)!.rank));
    return _Plan(apply, held, outdated);
  }

  Future<bool> _isDeleted(String key, Set<String> deletedInBatch) async {
    if (deletedInBatch.contains(key)) {
      return true;
    }
    final int slash = key.indexOf('/');
    final SyncRecord? local = await store.find(key.substring(0, slash), key.substring(slash + 1));
    return local?.isDeleted ?? false;
  }
}

class _Plan {
  const _Plan(this.apply, this.held, this.outdated);

  final List<SyncRecord> apply;
  final List<SyncRecord> held;
  final int outdated;
}
