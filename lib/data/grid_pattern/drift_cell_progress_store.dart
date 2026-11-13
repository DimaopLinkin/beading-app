import 'dart:async';
import 'dart:typed_data';

import 'package:beading/core/clock.dart';
import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/grid_patterns_dao.dart';
import 'package:beading/data/grid_pattern/cell_blocks_writer.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/domain/grid_pattern/cell_progress_store.dart';
import 'package:beading/domain/settings/device_id_provider.dart';

/// Прогресс вышивки по клеткам: блоки в `grid_progress_cells`.
class DriftCellProgressStore implements CellProgressStore {
  DriftCellProgressStore({
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
  Future<Result<CellProgress>> load(String patternId) async {
    final Result<Result<CellProgress>> guarded = await guardStorage<Result<CellProgress>>(() async {
      final GridPatternRow? pattern = await _dao.findAlive(patternId);
      if (pattern == null) {
        return Err<CellProgress>(NotFoundFailure('Сетка $patternId не найдена'));
      }
      final List<GridProgressCellRecord> rows = await _dao.aliveProgressCells(patternId);
      return Success<CellProgress>(
        CellProgress(
          width: pattern.width,
          blocks: <int, Uint8List>{for (final GridProgressCellRecord r in rows) r.blockIndex: r.bits},
        ),
      );
    });
    return guarded.fold(onSuccess: (inner) => inner, onFailure: Err<CellProgress>.new);
  }

  @override
  Stream<CellProgress> watch(String patternId) => Stream<CellProgress>.multi((controller) {
    CellProgress? previous;
    final StreamSubscription<Result<CellProgress>> subscription = _dao
        .watchCellProgressChanges()
        .asyncMap<Result<CellProgress>>((_) => load(patternId))
        .listen(
          (result) {
            switch (result) {
              case Err<CellProgress>(failure: NotFoundFailure()):
                if (previous != const CellProgress.none()) {
                  previous = const CellProgress.none();
                  controller.add(const CellProgress.none());
                }
              case Err<CellProgress>(:final Failure failure):
                controller.addError(StateError(failure.message));
              case Success<CellProgress>(:final CellProgress value):
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
  Future<Result<void>> setCells(String patternId, Iterable<CellPosition> cells, {required bool done}) async {
    final Result<String> deviceId = await _deviceIds.deviceId();
    if (deviceId case Err<String>(:final Failure failure)) {
      return Err<void>(failure);
    }
    final Result<Result<void>> guarded = await guardStorage<Result<void>>(
      () => _dao.transaction(() async {
        final GridPatternRow? pattern = await _dao.findAlive(patternId);
        if (pattern == null) {
          return Err<void>(NotFoundFailure('Сетка $patternId не найдена'));
        }
        final CellProgress before = CellProgress(
          width: pattern.width,
          blocks: <int, Uint8List>{
            for (final GridProgressCellRecord r in await _dao.aliveProgressCells(patternId)) r.blockIndex: r.bits,
          },
        );
        final Map<int, Uint8List> changed = before.withCells(cells, done: done).changedBlocksFrom(before);
        if (changed.isNotEmpty) {
          await writeCellBlocks(
            _dao,
            ids: _ids,
            patternId: patternId,
            blocks: changed,
            now: _clock.now().millisecondsSinceEpoch,
            deviceId: deviceId.valueOrNull!,
          );
        }
        return const Success<void>(null);
      }),
    );
    return guarded.fold(onSuccess: (inner) => inner, onFailure: Err<void>.new);
  }

  @override
  Future<Result<void>> writeBlocks(String patternId, Map<int, Uint8List> blocks) async {
    final Result<String> deviceId = await _deviceIds.deviceId();
    if (deviceId case Err<String>(:final Failure failure)) {
      return Err<void>(failure);
    }
    final Result<Result<void>> guarded = await guardStorage<Result<void>>(
      () => _dao.transaction(() async {
        if (await _dao.findAlive(patternId) == null) {
          return Err<void>(NotFoundFailure('Сетка $patternId не найдена'));
        }
        await writeCellBlocks(
          _dao,
          ids: _ids,
          patternId: patternId,
          blocks: blocks,
          now: _clock.now().millisecondsSinceEpoch,
          deviceId: deviceId.valueOrNull!,
        );
        return const Success<void>(null);
      }),
    );
    return guarded.fold(onSuccess: (inner) => inner, onFailure: Err<void>.new);
  }
}
