import 'package:beading/data/db/tables/sync_columns.dart';
import 'package:drift/drift.dart';

/// Запас бисера: одна живая запись на цвет (бренд + артикул), граммов. Синхронизируется как остальное.
@DataClassName('BeadStockRow')
class BeadStock extends Table with UuidIdColumn, SyncColumns {
  TextColumn get brand => text()();

  TextColumn get code => text()();

  /// Граммов осталось; больше нуля.
  RealColumn get grams => real()();
}
