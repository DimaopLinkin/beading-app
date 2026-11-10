import 'package:beading/data/db/tables/projects_table.dart';
import 'package:beading/data/db/tables/sync_columns.dart';
import 'package:drift/drift.dart';

/// Сессии работы над проектом (T19): учёт времени плетения. Время — UTC, миллисекунды с эпохи.
@DataClassName('WorkSessionRow')
class WorkSessions extends Table with UuidIdColumn, SyncColumns {
  TextColumn get projectId => text().references(Projects, #id)();

  IntColumn get startedAt => integer()();

  /// Последний известный момент работы; `NULL`, пока сессию ни разу не обновили.
  IntColumn get endedAt => integer().nullable()();
}
