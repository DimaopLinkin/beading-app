import 'package:beading/core/clock.dart';
import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/image_patterns_dao.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';
import 'package:beading/domain/image_pattern/image_pattern_repository.dart';
import 'package:beading/domain/settings/device_id_provider.dart';

/// Схемы-картинки в таблицах `image_patterns` и `image_pattern_pages`.
/// Сам ставит `created_at`, `updated_at` и `device_id`.
class DriftImagePatternRepository implements ImagePatternRepository {
  DriftImagePatternRepository({
    required ImagePatternsDao dao,
    required DeviceIdProvider deviceIds,
    required Clock clock,
  }) : _dao = dao,
       _deviceIds = deviceIds,
       _clock = clock;

  final ImagePatternsDao _dao;
  final DeviceIdProvider _deviceIds;
  final Clock _clock;

  @override
  Future<Result<ImagePattern>> getByProject(String projectId) async {
    final Result<Result<ImagePattern>> guarded = await guardStorage<Result<ImagePattern>>(() async {
      final ImagePatternRow? row = await _dao.findAliveByProject(projectId);
      if (row == null) {
        return Err<ImagePattern>(NotFoundFailure('У проекта $projectId нет схемы'));
      }
      final List<ImagePatternPageRow> pages = await _dao.alivePages(row.id);
      return Success<ImagePattern>(
        ImagePattern(
          id: row.id,
          projectId: row.projectId,
          pages: pages
              .map((p) => ImagePatternPage(id: p.id, path: p.path, width: p.width, height: p.height))
              .toList(growable: false),
        ),
      );
    });
    return guarded.fold(onSuccess: (inner) => inner, onFailure: Err<ImagePattern>.new);
  }

  @override
  Future<Result<void>> save(ImagePattern pattern) => _withDeviceId(
    (deviceId) => guardStorage<void>(() {
      final int now = _clock.now().millisecondsSinceEpoch;
      return _dao.insertAll(
        ImagePatternsCompanion.insert(
          id: pattern.id,
          projectId: pattern.projectId,
          createdAt: now,
          updatedAt: now,
          deviceId: deviceId,
        ),
        <ImagePatternPagesCompanion>[
          for (final (int position, ImagePatternPage page) in pattern.pages.indexed)
            ImagePatternPagesCompanion.insert(
              id: page.id,
              patternId: pattern.id,
              position: position,
              path: page.path,
              width: page.width,
              height: page.height,
              createdAt: now,
              updatedAt: now,
              deviceId: deviceId,
            ),
        ],
      );
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
