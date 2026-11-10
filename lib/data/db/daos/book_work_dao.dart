import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/tables/book_work_tables.dart';
import 'package:beading/data/db/tables/image_pattern_tables.dart';
import 'package:drift/drift.dart';

part 'book_work_dao.g.dart';

@DriftAccessor(tables: <Type>[PageWorkStates, BookWorkStates, ImagePatternPages])
class BookWorkDao extends DatabaseAccessor<AppDatabase> with _$BookWorkDaoMixin {
  BookWorkDao(super.attachedDatabase);

  /// Живое состояние открытой страницы схемы.
  Future<BookWorkStateRow?> aliveBookState(String patternId) =>
      (select(bookWorkStates)..where((t) => t.id.equals(patternId) & t.deletedAt.isNull())).getSingleOrNull();

  /// Живые состояния страниц схемы.
  Future<List<PageWorkStateRow>> alivePageStates(String patternId) async {
    final List<ImagePatternPageRow> pages = await (select(
      imagePatternPages,
    )..where((t) => t.patternId.equals(patternId))).get();
    final List<String> ids = pages.map((p) => p.id).toList(growable: false);
    return (select(pageWorkStates)..where((t) => t.deletedAt.isNull() & t.id.isIn(ids))).get();
  }

  /// Создаёт или заменяет состояние страницы; время создания и устройство-автор первой записи не трогает.
  Future<void> upsertPageState(PageWorkStatesCompanion row, {required PageWorkStatesCompanion update}) =>
      into(pageWorkStates).insert(row, onConflict: DoUpdate<$PageWorkStatesTable, PageWorkStateRow>((_) => update));

  Future<void> upsertBookState(BookWorkStatesCompanion row, {required BookWorkStatesCompanion update}) =>
      into(bookWorkStates).insert(row, onConflict: DoUpdate<$BookWorkStatesTable, BookWorkStateRow>((_) => update));
}
