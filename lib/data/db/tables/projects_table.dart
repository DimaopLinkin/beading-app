import 'package:beading/data/db/tables/sync_columns.dart';
import 'package:drift/drift.dart';

/// Проекты — корень библиотеки. Перечисления хранятся именами (менять имена нельзя: они на устройствах).
@DataClassName('ProjectRow')
class Projects extends Table with UuidIdColumn, SyncColumns {
  TextColumn get name => text()();

  /// `beading` / `crossStitch`.
  TextColumn get craft => text().withDefault(const Constant<String>('beading'))();

  /// `idea` / `inProgress` / `done`.
  TextColumn get status => text().withDefault(const Constant<String>('idea'))();

  TextColumn get technique => text()();

  /// `image` / `grid` / `steps`.
  TextColumn get contentKind => text()();

  TextColumn get notes => text().withDefault(const Constant<String>(''))();

  TextColumn get coverPath => text().nullable()();

  /// UTC, миллисекунды с эпохи.
  IntColumn get lastWorkedAt => integer()();
}
