import 'package:beading/core/id_generator.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/grid_patterns_dao.dart';
import 'package:drift/drift.dart';

/// Записывает блоки отметок клеток: непустой блок — вставка или обновление (оживляет надгробие), пустой список байт —
/// надгробие. Вызывать внутри транзакции.
Future<void> writeCellBlocks(
  GridPatternsDao dao, {
  required IdGenerator ids,
  required String patternId,
  required Map<int, Uint8List> blocks,
  required int now,
  required String deviceId,
}) async {
  final Map<int, GridProgressCellRecord> existing = <int, GridProgressCellRecord>{
    for (final GridProgressCellRecord r in await dao.allProgressCells(patternId)) r.blockIndex: r,
  };
  for (final MapEntry<int, Uint8List> e in blocks.entries) {
    final GridProgressCellRecord? row = existing[e.key];
    if (e.value.isEmpty) {
      if (row != null && row.deletedAt == null) {
        await (dao.update(dao.gridProgressCells)..where((t) => t.id.equals(row.id))).write(
          GridProgressCellsCompanion(
            updatedAt: Value<int>(now),
            deletedAt: Value<int?>(now),
            deviceId: Value<String>(deviceId),
          ),
        );
      }
    } else if (row == null) {
      await dao
          .into(dao.gridProgressCells)
          .insert(
            GridProgressCellsCompanion.insert(
              id: ids.next(),
              gridPatternId: patternId,
              blockIndex: e.key,
              bits: e.value,
              createdAt: now,
              updatedAt: now,
              deviceId: deviceId,
            ),
          );
    } else {
      await (dao.update(dao.gridProgressCells)..where((t) => t.id.equals(row.id))).write(
        GridProgressCellsCompanion(
          bits: Value<Uint8List>(e.value),
          updatedAt: Value<int>(now),
          deletedAt: const Value<int?>(null),
          deviceId: Value<String>(deviceId),
        ),
      );
    }
  }
}
