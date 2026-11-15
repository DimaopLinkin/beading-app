import 'package:beading/core/clock.dart';
import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/step_patterns_dao.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/step_pattern_codec.dart';
import 'package:beading/domain/steps/step_pattern_repository.dart';
import 'package:drift/drift.dart';

/// Инструкции в таблицах `step_patterns`, `step_images` и `step_progress`.
/// Сам ставит `created_at`, `updated_at` и `device_id`.
class DriftStepPatternRepository implements StepPatternRepository {
  DriftStepPatternRepository({required StepPatternsDao dao, required DeviceIdProvider deviceIds, required Clock clock})
    : _dao = dao,
      _deviceIds = deviceIds,
      _clock = clock;

  final StepPatternsDao _dao;
  final DeviceIdProvider _deviceIds;
  final Clock _clock;

  @override
  Future<Result<StepPattern>> getByProject(String projectId) async {
    final Result<Result<StepPattern>> guarded = await guardStorage<Result<StepPattern>>(() async {
      final StepPatternRow? row = await _dao.findAliveByProject(projectId);
      if (row == null) {
        return Err<StepPattern>(NotFoundFailure('У проекта $projectId нет инструкции'));
      }
      final List<StepImageRow> images = await _dao.aliveImages(row.id);
      return StepPatternCodec.decode(
        row.body,
        id: row.id,
        projectId: row.projectId,
        templateId: row.templateId,
        images: <StepImage>[
          for (final StepImageRow i in images) StepImage(id: i.id, path: i.path, width: i.width, height: i.height),
        ],
      );
    });
    return guarded.fold(onSuccess: (inner) => inner, onFailure: Err<StepPattern>.new);
  }

  @override
  Future<Result<void>> save(StepPattern pattern) async {
    // `project_id` уникален и среди надгробий: другой `id` для того же проекта — ошибка, тот же `id` оживляет запись.
    final Result<StepPatternRow?> found = await guardStorage<StepPatternRow?>(
      () => _dao.findAnyByProject(pattern.projectId),
    );
    if (found case Err<StepPatternRow?>(:final Failure failure)) {
      return Err<void>(failure);
    }
    final StepPatternRow? existing = found.valueOrNull;
    if (existing != null && existing.id != pattern.id) {
      return Err<void>(ValidationFailure('У проекта ${pattern.projectId} уже есть инструкция ${existing.id}'));
    }
    return _write(pattern);
  }

  Future<Result<void>> _write(StepPattern pattern) => _withDeviceId(
    (deviceId) => guardStorage<void>(() {
      final int now = _clock.now().millisecondsSinceEpoch;
      final String body = StepPatternCodec.encode(pattern);
      return _dao.transaction(() async {
        await _dao.upsertPattern(
          StepPatternsCompanion.insert(
            id: pattern.id,
            projectId: pattern.projectId,
            body: body,
            bodyVersion: StepPatternCodec.version,
            templateId: Value<String?>(pattern.templateId),
            createdAt: now,
            updatedAt: now,
            deviceId: deviceId,
          ),
          update: StepPatternsCompanion(
            body: Value<String>(body),
            bodyVersion: const Value<int>(StepPatternCodec.version),
            templateId: Value<String?>(pattern.templateId),
            updatedAt: Value<int>(now),
            deletedAt: const Value<int?>(null),
            deviceId: Value<String>(deviceId),
          ),
        );
        final Set<String> keep = <String>{for (final StepImage i in pattern.images) i.id};
        final List<StepImageRow> existing = await _dao.allImages(pattern.id);
        await _dao.tombstoneImages(
          <String>[
            for (final StepImageRow r in existing)
              if (!keep.contains(r.id)) r.id,
          ],
          nowMs: now,
          deviceId: deviceId,
        );
        final Map<String, StepImageRow> byId = <String, StepImageRow>{for (final StepImageRow r in existing) r.id: r};
        for (final StepImage image in pattern.images) {
          final StepImageRow? old = byId[image.id];
          if (old != null &&
              old.deletedAt == null &&
              old.path == image.path &&
              old.width == image.width &&
              old.height == image.height) {
            continue; // не менялась
          }
          await _dao.upsertImage(
            StepImagesCompanion.insert(
              id: image.id,
              patternId: pattern.id,
              path: image.path,
              width: image.width,
              height: image.height,
              createdAt: now,
              updatedAt: now,
              deviceId: deviceId,
            ),
            update: StepImagesCompanion(
              path: Value<String>(image.path),
              width: Value<int>(image.width),
              height: Value<int>(image.height),
              updatedAt: Value<int>(now),
              deletedAt: const Value<int?>(null),
              deviceId: Value<String>(deviceId),
            ),
          );
        }
      });
    }),
  );

  @override
  Future<Result<void>> deleteByProject(String projectId) => _withDeviceId(
    (deviceId) => guardStorage<void>(
      () =>
          _dao.tombstoneByProject(projectId: projectId, nowMs: _clock.now().millisecondsSinceEpoch, deviceId: deviceId),
    ),
  );

  Future<Result<void>> _withDeviceId(Future<Result<void>> Function(String deviceId) action) async {
    final Result<String> id = await _deviceIds.deviceId();
    return switch (id) {
      Err<String>(:final failure) => Err<void>(failure),
      Success<String>(:final String value) => action(value),
    };
  }
}
