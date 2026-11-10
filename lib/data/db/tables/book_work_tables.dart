import 'package:beading/data/db/tables/image_pattern_tables.dart';
import 'package:beading/data/db/tables/sync_columns.dart';
import 'package:drift/drift.dart';

/// Линейка и вид одной страницы схемы (T07). Одна запись на страницу: `id` равен `id` страницы.
@DataClassName('PageWorkStateRow')
class PageWorkStates extends Table with UuidIdColumn, SyncColumns {
  @override
  TextColumn get id => text().references(ImagePatternPages, #id)();

  @override
  String get tableName => 'page_work_states';

  /// Положение линейки, px картинки страницы.
  RealColumn get rulerTop => real()();

  RealColumn get rulerHeight => real()();

  RealColumn get rulerStep => real()();

  /// Номер ряда с 1.
  IntColumn get rulerRow => integer()();

  /// Имя значения `RulerHighlight`.
  TextColumn get highlight => text()();

  /// Зум и сдвиг вида.
  RealColumn get viewScale => real()();

  RealColumn get viewDx => real()();

  RealColumn get viewDy => real()();
}

/// Какая страница схемы открыта. Одна запись на схему: `id` равен `id` схемы (`image_patterns`).
@DataClassName('BookWorkStateRow')
class BookWorkStates extends Table with UuidIdColumn, SyncColumns {
  @override
  TextColumn get id => text().references(ImagePatterns, #id)();

  @override
  String get tableName => 'book_work_states';

  TextColumn get currentPageId => text().references(ImagePatternPages, #id)();
}
