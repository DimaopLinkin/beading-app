import 'package:beading/data/db/tables/sync_columns.dart';
import 'package:drift/drift.dart';

/// Настройки: пары «ключ — значение» со служебными колонками синхронизации.
@DataClassName('SettingRow')
class Settings extends Table with SyncColumns {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}
