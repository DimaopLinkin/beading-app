import 'package:beading/core/clock.dart';
import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/floss_stock_dao.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/floss_stock/floss_stock_entry.dart';
import 'package:beading/domain/floss_stock/floss_stock_repository.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:drift/drift.dart';

/// Запас мулине в таблице `floss_stock`. Служебные колонки синхронизации ставит сам; убранная нитка остаётся
/// надгробием.
class DriftFlossStockRepository implements FlossStockRepository {
  DriftFlossStockRepository({
    required FlossStockDao dao,
    required DeviceIdProvider deviceIds,
    required Clock clock,
    required IdGenerator ids,
  }) : _dao = dao,
       _deviceIds = deviceIds,
       _clock = clock,
       _ids = ids;

  final FlossStockDao _dao;
  final DeviceIdProvider _deviceIds;
  final Clock _clock;
  final IdGenerator _ids;

  @override
  Stream<List<FlossStockEntry>> watchAll() => _dao.watchAlive().map(_toDomain);

  @override
  Future<Result<List<FlossStockEntry>>> all() => guardStorage<List<FlossStockEntry>>(
    () async => _toDomain(await _dao.alive()),
  );

  @override
  Future<Result<void>> setSkeins(CatalogRef ref, double skeins) async {
    if (!skeins.isFinite || skeins > FlossStockRepository.maxSkeins) {
      return Err<void>(ValidationFailure('Мотков должно быть число от 0 до ${FlossStockRepository.maxSkeins.toInt()}'));
    }
    final Result<String> deviceId = await _deviceIds.deviceId();
    if (deviceId case Err<String>(:final Failure failure)) {
      return Err<void>(failure);
    }
    final Result<Result<void>> guarded = await guardStorage<Result<void>>(() async {
      final int now = _clock.now().millisecondsSinceEpoch;
      final String device = deviceId.valueOrNull!;
      final FlossStockRow? existing = await _dao.findAlive(ref.brand, ref.code);
      if (skeins <= 0) {
        if (existing != null) {
          await _dao.updateRow(
            existing.id,
            FlossStockCompanion(
              updatedAt: Value<int>(now),
              deletedAt: Value<int?>(now),
              deviceId: Value<String>(device),
            ),
          );
        }
        return const Success<void>(null);
      }
      if (existing == null) {
        await _dao.insertRow(
          FlossStockCompanion.insert(
            id: _ids.next(),
            brand: ref.brand,
            code: ref.code,
            skeins: skeins,
            createdAt: now,
            updatedAt: now,
            deviceId: device,
          ),
        );
      } else {
        await _dao.updateRow(
          existing.id,
          FlossStockCompanion(
            skeins: Value<double>(skeins),
            updatedAt: Value<int>(now),
            deviceId: Value<String>(device),
          ),
        );
      }
      return const Success<void>(null);
    });
    return guarded.fold(onSuccess: (inner) => inner, onFailure: Err<void>.new);
  }

  @override
  Future<Result<void>> merge(List<FlossStockEntry> incoming) async {
    final Result<String> deviceId = await _deviceIds.deviceId();
    if (deviceId case Err<String>(:final Failure failure)) {
      return Err<void>(failure);
    }
    final Result<Result<void>> guarded = await guardStorage<Result<void>>(() async {
      final int now = _clock.now().millisecondsSinceEpoch;
      final String device = deviceId.valueOrNull!;
      for (final FlossStockEntry entry in incoming) {
        final DateTime? at = entry.updatedAt;
        if (at == null ||
            !entry.skeins.isFinite ||
            entry.skeins <= 0 ||
            entry.skeins > FlossStockRepository.maxSkeins) {
          continue;
        }
        final int atMs = at.millisecondsSinceEpoch;
        final FlossStockRow? existing = await _dao.findAlive(entry.ref.brand, entry.ref.code);
        if (existing == null) {
          await _dao.insertRow(
            FlossStockCompanion.insert(
              id: _ids.next(),
              brand: entry.ref.brand,
              code: entry.ref.code,
              skeins: entry.skeins,
              createdAt: now,
              updatedAt: atMs,
              deviceId: device,
            ),
          );
        } else if (atMs > existing.updatedAt) {
          await _dao.updateRow(
            existing.id,
            FlossStockCompanion(
              skeins: Value<double>(entry.skeins),
              updatedAt: Value<int>(atMs),
              deviceId: Value<String>(device),
            ),
          );
        }
      }
      return const Success<void>(null);
    });
    return guarded.fold(onSuccess: (inner) => inner, onFailure: Err<void>.new);
  }

  List<FlossStockEntry> _toDomain(List<FlossStockRow> rows) => <FlossStockEntry>[
    for (final FlossStockRow row in rows)
      FlossStockEntry(
        ref: CatalogRef(brand: row.brand, code: row.code),
        skeins: row.skeins,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
      ),
  ];
}
