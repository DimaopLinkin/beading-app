import 'package:beading/core/clock.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/step_patterns_dao.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:beading/domain/steps/step_pattern_repository.dart';
import 'package:beading/domain/steps/steps_progress.dart';
import 'package:drift/drift.dart';

/// Курсор прогресса в таблице `step_progress`: одна строка на инструкцию, `id` равен `id` инструкции.
class DriftStepsProgressStore implements StepsProgressStore {
  DriftStepsProgressStore({required StepPatternsDao dao, required DeviceIdProvider deviceIds, required Clock clock})
    : _dao = dao,
      _deviceIds = deviceIds,
      _clock = clock;

  final StepPatternsDao _dao;
  final DeviceIdProvider _deviceIds;
  final Clock _clock;

  @override
  Future<Result<StepsProgress?>> load(String patternId) => guardStorage<StepsProgress?>(() async {
    final StepProgressRow? row = await _dao.aliveProgress(patternId);
    return row == null
        ? null
        : StepsProgress(
            sectionId: row.sectionId,
            sectionPass: row.sectionPass,
            stepId: row.stepId,
            stepPass: row.stepPass,
            finished: row.finished,
          );
  });

  @override
  Future<Result<void>> save(String patternId, StepsProgress progress) async {
    final Result<String> device = await _deviceIds.deviceId();
    if (device case Err<String>(:final failure)) {
      return Err<void>(failure);
    }
    final String deviceId = device.valueOrNull!;
    return guardStorage<void>(() {
      final int now = _clock.now().millisecondsSinceEpoch;
      return _dao.upsertProgress(
        StepProgressRowsCompanion.insert(
          id: patternId,
          sectionId: progress.sectionId,
          sectionPass: progress.sectionPass,
          stepId: progress.stepId,
          stepPass: progress.stepPass,
          finished: progress.finished,
          createdAt: now,
          updatedAt: now,
          deviceId: deviceId,
        ),
        update: StepProgressRowsCompanion(
          sectionId: Value<String>(progress.sectionId),
          sectionPass: Value<int>(progress.sectionPass),
          stepId: Value<String>(progress.stepId),
          stepPass: Value<int>(progress.stepPass),
          finished: Value<bool>(progress.finished),
          updatedAt: Value<int>(now),
          deletedAt: const Value<int?>(null),
          deviceId: Value<String>(deviceId),
        ),
      );
    });
  }
}
