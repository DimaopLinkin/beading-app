import 'package:beading/core/clock.dart';
import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/bead_stock_dao.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/bead_stock/bead_stock_entry.dart';
import 'package:beading/domain/bead_stock/bead_stock_repository.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:drift/drift.dart';

/// Запас бисера в таблице `bead_stock`. Служебные колонки синхронизации ставит сам; убранный цвет остаётся
/// надгробием.
class DriftBeadStockRepository implements BeadStockRepository {
  DriftBeadStockRepository({
    required BeadStockDao dao,
    required DeviceIdProvider deviceIds,
    required Clock clock,
    required IdGenerator ids,
  }) : _dao = dao,
       _deviceIds = deviceIds,
       _clock = clock,
       _ids = ids;

  final BeadStockDao _dao;
  final DeviceIdProvider _deviceIds;
  final Clock _clock;
  final IdGenerator _ids;

  @override
  Stream<List<BeadStockEntry>> watchAll() => _dao.watchAlive().map(_toDomain);

  @override
  Future<Result<List<BeadStockEntry>>> all() => guardStorage<List<BeadStockEntry>>(
    () async => _toDomain(await _dao.alive()),
  );

  @override
  Future<Result<void>> setGrams(CatalogRef ref, double grams) async {
    if (!grams.isFinite || grams > BeadStockRepository.maxGrams) {
      return Err<void>(ValidationFailure('Граммов должно быть число от 0 до ${BeadStockRepository.maxGrams.toInt()}'));
    }
    final Result<String> deviceId = await _deviceIds.deviceId();
    if (deviceId case Err<String>(:final Failure failure)) {
      return Err<void>(failure);
    }
    final Result<Result<void>> guarded = await guardStorage<Result<void>>(() async {
      final int now = _clock.now().millisecondsSinceEpoch;
      final String device = deviceId.valueOrNull!;
      final BeadStockRow? existing = await _dao.findAlive(ref.brand, ref.code);
      if (grams <= 0) {
        if (existing != null) {
          await _dao.updateRow(
            existing.id,
            BeadStockCompanion(
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
          BeadStockCompanion.insert(
            id: _ids.next(),
            brand: ref.brand,
            code: ref.code,
            grams: grams,
            createdAt: now,
            updatedAt: now,
            deviceId: device,
          ),
        );
      } else {
        await _dao.updateRow(
          existing.id,
          BeadStockCompanion(
            grams: Value<double>(grams),
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
  Future<Result<void>> merge(List<BeadStockEntry> incoming) async {
    final Result<String> deviceId = await _deviceIds.deviceId();
    if (deviceId case Err<String>(:final Failure failure)) {
      return Err<void>(failure);
    }
    final Result<Result<void>> guarded = await guardStorage<Result<void>>(() async {
      final int now = _clock.now().millisecondsSinceEpoch;
      final String device = deviceId.valueOrNull!;
      for (final BeadStockEntry entry in incoming) {
        final DateTime? at = entry.updatedAt;
        if (at == null || !entry.grams.isFinite || entry.grams <= 0 || entry.grams > BeadStockRepository.maxGrams) {
          continue;
        }
        final int atMs = at.millisecondsSinceEpoch;
        final BeadStockRow? existing = await _dao.findAlive(entry.ref.brand, entry.ref.code);
        if (existing == null) {
          await _dao.insertRow(
            BeadStockCompanion.insert(
              id: _ids.next(),
              brand: entry.ref.brand,
              code: entry.ref.code,
              grams: entry.grams,
              createdAt: now,
              updatedAt: atMs,
              deviceId: device,
            ),
          );
        } else if (atMs > existing.updatedAt) {
          await _dao.updateRow(
            existing.id,
            BeadStockCompanion(
              grams: Value<double>(entry.grams),
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

  List<BeadStockEntry> _toDomain(List<BeadStockRow> rows) => <BeadStockEntry>[
    for (final BeadStockRow row in rows)
      BeadStockEntry(
        ref: CatalogRef(brand: row.brand, code: row.code),
        grams: row.grams,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
      ),
  ];
}
