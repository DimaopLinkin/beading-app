import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/tables/image_pattern_tables.dart';
import 'package:drift/drift.dart';

part 'image_patterns_dao.g.dart';

@DriftAccessor(tables: <Type>[ImagePatterns, ImagePatternPages])
class ImagePatternsDao extends DatabaseAccessor<AppDatabase> with _$ImagePatternsDaoMixin {
  ImagePatternsDao(super.attachedDatabase);

  /// Живая схема проекта.
  Future<ImagePatternRow?> findAliveByProject(String projectId) =>
      (select(imagePatterns)..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull())).getSingleOrNull();

  /// Живые страницы схемы по порядку.
  Future<List<ImagePatternPageRow>> alivePages(String patternId) =>
      (select(imagePatternPages)
            ..where((t) => t.patternId.equals(patternId) & t.deletedAt.isNull())
            ..orderBy(<OrderingTerm Function($ImagePatternPagesTable)>[(t) => OrderingTerm.asc(t.position)]))
          .get();

  /// Схема и страницы одной транзакцией.
  Future<void> insertAll(ImagePatternsCompanion pattern, List<ImagePatternPagesCompanion> pages) => transaction(() async {
    await into(imagePatterns).insert(pattern);
    for (final ImagePatternPagesCompanion page in pages) {
      await into(imagePatternPages).insert(page);
    }
  });

  /// Ставит надгробие схеме проекта и её страницам.
  Future<void> tombstoneByProject({required String projectId, required int nowMs, required String deviceId}) =>
      transaction(() async {
        final ImagePatternRow? pattern = await findAliveByProject(projectId);
        if (pattern == null) {
          return;
        }
        await (update(imagePatternPages)..where((t) => t.patternId.equals(pattern.id) & t.deletedAt.isNull())).write(
          ImagePatternPagesCompanion(
            updatedAt: Value<int>(nowMs),
            deletedAt: Value<int?>(nowMs),
            deviceId: Value<String>(deviceId),
          ),
        );
        await (update(imagePatterns)..where((t) => t.id.equals(pattern.id))).write(
          ImagePatternsCompanion(
            updatedAt: Value<int>(nowMs),
            deletedAt: Value<int?>(nowMs),
            deviceId: Value<String>(deviceId),
          ),
        );
      });
}
