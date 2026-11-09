import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/tables/easter_egg_log_table.dart';
import 'package:drift/drift.dart';

part 'easter_egg_log_dao.g.dart';

@DriftAccessor(tables: <Type>[EasterEggLogEntries])
class EasterEggLogDao extends DatabaseAccessor<AppDatabase> with _$EasterEggLogDaoMixin {
  EasterEggLogDao(super.attachedDatabase);

  Future<List<EasterEggLogRow>> all() => (select(easterEggLogEntries)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  Future<void> insertRow({required String group, required String eggId, required int shownAtMs}) =>
      into(easterEggLogEntries).insert(
        EasterEggLogEntriesCompanion.insert(eggGroup: group, eggId: eggId, shownAt: shownAtMs),
      );
}
