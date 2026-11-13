import 'package:beading/data/db/tables/sync_columns.dart';
import 'package:drift/drift.dart';

/// Запас мулине: одна живая запись на нитку (бренд + номер), мотков дробным числом. Синхронизируется как остальное.
@DataClassName('FlossStockRow')
class FlossStock extends Table with UuidIdColumn, SyncColumns {
  TextColumn get brand => text()();

  TextColumn get code => text()();

  /// Мотков осталось; больше нуля.
  RealColumn get skeins => real()();
}
