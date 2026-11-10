import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/tables/grid_pattern_tables.dart';
import 'package:drift/drift.dart';

part 'grid_patterns_dao.g.dart';

@DriftAccessor(tables: <Type>[GridPatterns, PatternColors, GridProgressRows])
class GridPatternsDao extends DatabaseAccessor<AppDatabase> with _$GridPatternsDaoMixin {
  GridPatternsDao(super.attachedDatabase);

  /// Живая схема проекта.
  Future<GridPatternRow?> findAliveByProject(String projectId) =>
      (select(gridPatterns)..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull())).getSingleOrNull();

  /// Живая схема по id.
  Future<GridPatternRow?> findAlive(String id) =>
      (select(gridPatterns)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  /// Строка по id, включая удалённую.
  Future<GridPatternRow?> find(String id) => (select(gridPatterns)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Размеры живой схемы проекта без чтения BLOB.
  Future<({String id, int width, int height})?> summaryByProject(String projectId) async {
    final JoinedSelectStatement<GridPatterns, GridPatternRow> query = selectOnly(gridPatterns)
      ..addColumns(<Expression<Object>>[gridPatterns.id, gridPatterns.width, gridPatterns.height])
      ..where(gridPatterns.projectId.equals(projectId) & gridPatterns.deletedAt.isNull());
    final TypedResult? row = await query.getSingleOrNull();
    if (row == null) {
      return null;
    }
    return (
      id: row.read(gridPatterns.id)!,
      width: row.read(gridPatterns.width)!,
      height: row.read(gridPatterns.height)!,
    );
  }

  /// Живые цвета палитры по порядку.
  Future<List<PatternColorRow>> aliveColors(String patternId) =>
      (select(patternColors)
            ..where((t) => t.gridPatternId.equals(patternId) & t.deletedAt.isNull())
            ..orderBy(<OrderingTerm Function($PatternColorsTable)>[(t) => OrderingTerm.asc(t.position)]))
          .get();

  /// Все цвета схемы, включая с надгробием (для обновления на месте).
  Future<List<PatternColorRow>> allColors(String patternId) =>
      (select(patternColors)..where((t) => t.gridPatternId.equals(patternId))).get();

  /// Идентификатор живой схемы проекта при каждом изменении схемы или палитры (отметки рядов не будят, «остановилась здесь» будит — это запись в `grid_patterns`); `null`, пока схемы нет.
  Stream<String?> watchAliveIdByProject(String projectId) => customSelect(
    'SELECT id FROM grid_patterns WHERE project_id = ?1 AND deleted_at IS NULL',
    variables: <Variable<Object>>[Variable<String>(projectId)],
    readsFrom: <ResultSetImplementation<dynamic, dynamic>>{gridPatterns, patternColors},
  ).watch().map((rows) => rows.isEmpty ? null : rows.single.read<String>('id'));

  /// Сигнал сразу и после каждого изменения схемы или отметок рядов.
  Stream<void> watchProgressChanges() => customSelect(
    'SELECT 1',
    readsFrom: <ResultSetImplementation<dynamic, dynamic>>{gridPatterns, gridProgressRows},
  ).watch();

  /// Ряды с отметкой (живые) по возрастанию.
  Future<List<GridProgressRowRecord>> aliveProgressRows(String patternId) =>
      (select(gridProgressRows)
            ..where((t) => t.gridPatternId.equals(patternId) & t.deletedAt.isNull())
            ..orderBy(<OrderingTerm Function($GridProgressRowsTable)>[(t) => OrderingTerm.asc(t.rowIndex)]))
          .get();

  Future<GridProgressRowRecord?> findProgressRow(String patternId, int rowIndex) => (select(
    gridProgressRows,
  )..where((t) => t.gridPatternId.equals(patternId) & t.rowIndex.equals(rowIndex))).getSingleOrNull();

  /// Ставит надгробие схеме проекта, её цветам и отметкам рядов.
  Future<void> tombstoneByProject({required String projectId, required int nowMs, required String deviceId}) =>
      transaction(() async {
        final GridPatternRow? pattern = await findAliveByProject(projectId);
        if (pattern == null) {
          return;
        }
        await (update(gridProgressRows)..where((t) => t.gridPatternId.equals(pattern.id) & t.deletedAt.isNull())).write(
          GridProgressRowsCompanion(
            updatedAt: Value<int>(nowMs),
            deletedAt: Value<int?>(nowMs),
            deviceId: Value<String>(deviceId),
          ),
        );
        await (update(patternColors)..where((t) => t.gridPatternId.equals(pattern.id) & t.deletedAt.isNull())).write(
          PatternColorsCompanion(
            updatedAt: Value<int>(nowMs),
            deletedAt: Value<int?>(nowMs),
            deviceId: Value<String>(deviceId),
          ),
        );
        await (update(gridPatterns)..where((t) => t.id.equals(pattern.id))).write(
          GridPatternsCompanion(
            updatedAt: Value<int>(nowMs),
            deletedAt: Value<int?>(nowMs),
            deviceId: Value<String>(deviceId),
          ),
        );
      });
}
