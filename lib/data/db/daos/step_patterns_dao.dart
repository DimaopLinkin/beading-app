import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/tables/step_pattern_tables.dart';
import 'package:drift/drift.dart';

part 'step_patterns_dao.g.dart';

@DriftAccessor(tables: <Type>[StepPatterns, StepImages, StepProgressRows])
class StepPatternsDao extends DatabaseAccessor<AppDatabase> with _$StepPatternsDaoMixin {
  StepPatternsDao(super.attachedDatabase);

  /// Живая инструкция проекта.
  Future<StepPatternRow?> findAliveByProject(String projectId) =>
      (select(stepPatterns)..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull())).getSingleOrNull();

  /// Инструкция проекта вместе с надгробием: уникальный ключ `project_id` не отличает живую от удалённой.
  Future<StepPatternRow?> findAnyByProject(String projectId) =>
      (select(stepPatterns)..where((t) => t.projectId.equals(projectId))).getSingleOrNull();

  /// Живые картинки инструкции в порядке создания.
  Future<List<StepImageRow>> aliveImages(String patternId) =>
      (select(stepImages)
            ..where((t) => t.patternId.equals(patternId) & t.deletedAt.isNull())
            ..orderBy(<OrderingTerm Function($StepImagesTable)>[
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();

  Future<List<StepImageRow>> allImages(String patternId) =>
      (select(stepImages)..where((t) => t.patternId.equals(patternId))).get();

  Future<StepProgressRow?> aliveProgress(String patternId) =>
      (select(stepProgressRows)..where((t) => t.id.equals(patternId) & t.deletedAt.isNull())).getSingleOrNull();

  Future<void> upsertPattern(StepPatternsCompanion row, {required StepPatternsCompanion update}) =>
      into(stepPatterns).insert(row, onConflict: DoUpdate((_) => update, target: <Column<Object>>[stepPatterns.id]));

  Future<void> upsertImage(StepImagesCompanion row, {required StepImagesCompanion update}) =>
      into(stepImages).insert(row, onConflict: DoUpdate((_) => update, target: <Column<Object>>[stepImages.id]));

  Future<void> upsertProgress(StepProgressRowsCompanion row, {required StepProgressRowsCompanion update}) => into(
    stepProgressRows,
  ).insert(row, onConflict: DoUpdate((_) => update, target: <Column<Object>>[stepProgressRows.id]));

  Future<void> tombstoneImages(Iterable<String> ids, {required int nowMs, required String deviceId}) =>
      (update(stepImages)..where((t) => t.id.isIn(ids) & t.deletedAt.isNull())).write(
        StepImagesCompanion(
          updatedAt: Value<int>(nowMs),
          deletedAt: Value<int?>(nowMs),
          deviceId: Value<String>(deviceId),
        ),
      );

  /// Ставит надгробие инструкции проекта, её картинкам и прогрессу.
  Future<void> tombstoneByProject({required String projectId, required int nowMs, required String deviceId}) =>
      transaction(() async {
        final StepPatternRow? pattern = await findAliveByProject(projectId);
        if (pattern == null) {
          return;
        }
        await (update(stepProgressRows)..where((t) => t.id.equals(pattern.id) & t.deletedAt.isNull())).write(
          StepProgressRowsCompanion(
            updatedAt: Value<int>(nowMs),
            deletedAt: Value<int?>(nowMs),
            deviceId: Value<String>(deviceId),
          ),
        );
        await (update(stepImages)..where((t) => t.patternId.equals(pattern.id) & t.deletedAt.isNull())).write(
          StepImagesCompanion(
            updatedAt: Value<int>(nowMs),
            deletedAt: Value<int?>(nowMs),
            deviceId: Value<String>(deviceId),
          ),
        );
        await (update(stepPatterns)..where((t) => t.id.equals(pattern.id))).write(
          StepPatternsCompanion(
            updatedAt: Value<int>(nowMs),
            deletedAt: Value<int?>(nowMs),
            deviceId: Value<String>(deviceId),
          ),
        );
      });
}
