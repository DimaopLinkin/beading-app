import 'dart:async';

import 'package:beading/core/clock.dart';
import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/grid_patterns_dao.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/grid_pattern/grid_progress_store.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:drift/drift.dart';

/// Прогресс по рядам: отметки в `grid_progress_rows`, «где остановилась» — в `grid_patterns`.
class DriftGridProgressStore implements GridProgressStore {
  DriftGridProgressStore({
    required GridPatternsDao dao,
    required DeviceIdProvider deviceIds,
    required Clock clock,
    required IdGenerator ids,
  }) : _dao = dao,
       _deviceIds = deviceIds,
       _clock = clock,
       _ids = ids;

  final GridPatternsDao _dao;
  final DeviceIdProvider _deviceIds;
  final Clock _clock;
  final IdGenerator _ids;

  @override
  Future<Result<GridProgress>> load(String patternId) => _guard<GridProgress>(() => _read(patternId));

  @override
  Stream<GridProgress> watch(String patternId) => Stream<GridProgress>.multi((controller) {
    GridProgress? previous;
    final StreamSubscription<Result<GridProgress>> subscription = _dao
        .watchProgressChanges()
        .asyncMap<Result<GridProgress>>((_) => load(patternId))
        .listen(
          (result) {
            switch (result) {
              case Err<GridProgress>(:final Failure failure):
                controller.addError(StateError(failure.message));
              case Success<GridProgress>(:final GridProgress value):
                if (value != previous) {
                  previous = value;
                  controller.add(value);
                }
            }
          },
          onError: controller.addError,
          onDone: controller.close,
        );
    controller.onCancel = subscription.cancel;
  });

  @override
  Future<Result<void>> markRow(String patternId, int row) => _write(patternId, (now, deviceId) async {
    final GridProgressRowRecord? existing = await _dao.findProgressRow(patternId, row);
    if (existing == null) {
      await _dao
          .into(_dao.gridProgressRows)
          .insert(
            GridProgressRowsCompanion.insert(
              id: _ids.next(),
              gridPatternId: patternId,
              rowIndex: row,
              completedAt: now,
              createdAt: now,
              updatedAt: now,
              deviceId: deviceId,
            ),
          );
    } else if (existing.deletedAt != null) {
      await (_dao.update(_dao.gridProgressRows)..where((t) => t.id.equals(existing.id))).write(
        GridProgressRowsCompanion(
          completedAt: Value<int>(now),
          updatedAt: Value<int>(now),
          deletedAt: const Value<int?>(null),
          deviceId: Value<String>(deviceId),
        ),
      );
    }
  });

  @override
  Future<Result<void>> unmarkRow(String patternId, int row) => _write(patternId, (now, deviceId) async {
    final GridProgressRowRecord? existing = await _dao.findProgressRow(patternId, row);
    if (existing != null && existing.deletedAt == null) {
      await (_dao.update(_dao.gridProgressRows)..where((t) => t.id.equals(existing.id))).write(
        GridProgressRowsCompanion(
          updatedAt: Value<int>(now),
          deletedAt: Value<int?>(now),
          deviceId: Value<String>(deviceId),
        ),
      );
    }
  });

  @override
  Future<Result<void>> setCurrent(String patternId, {required int row, int? bead}) =>
      _write(patternId, (now, deviceId) async {
        await (_dao.update(_dao.gridPatterns)..where((t) => t.id.equals(patternId))).write(
          GridPatternsCompanion(
            currentRow: Value<int?>(row),
            currentBead: Value<int?>(bead),
            updatedAt: Value<int>(now),
            deviceId: Value<String>(deviceId),
          ),
        );
      });

  Future<Result<void>> _write(String patternId, Future<void> Function(int now, String deviceId) action) async {
    final Result<String> deviceId = await _deviceIds.deviceId();
    if (deviceId case Err<String>(:final Failure failure)) {
      return Err<void>(failure);
    }
    return _guard<void>(
      () => _dao.transaction(() async {
        if (await _dao.findAlive(patternId) == null) {
          return Err<void>(NotFoundFailure('Сетка $patternId не найдена'));
        }
        await action(_clock.now().millisecondsSinceEpoch, deviceId.valueOrNull!);
        return const Success<void>(null);
      }),
    );
  }

  Future<Result<GridProgress>> _read(String patternId) async {
    final GridPatternRow? pattern = await _dao.findAlive(patternId);
    if (pattern == null) {
      return Err<GridProgress>(NotFoundFailure('Сетка $patternId не найдена'));
    }
    final List<GridProgressRowRecord> rows = await _dao.aliveProgressRows(patternId);
    return Success<GridProgress>(
      GridProgress(
        completedRows: <int>{for (final GridProgressRowRecord r in rows) r.rowIndex},
        currentRow: pattern.currentRow,
        currentBead: pattern.currentBead,
      ),
    );
  }
}

Future<Result<T>> _guard<T>(Future<Result<T>> Function() action) async {
  final Result<Result<T>> guarded = await guardStorage<Result<T>>(action);
  return guarded.fold(onSuccess: (inner) => inner, onFailure: Err<T>.new);
}
