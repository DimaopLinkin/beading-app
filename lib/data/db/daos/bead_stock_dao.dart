import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/tables/bead_stock_table.dart';
import 'package:drift/drift.dart';

part 'bead_stock_dao.g.dart';

@DriftAccessor(tables: <Type>[BeadStock])
class BeadStockDao extends DatabaseAccessor<AppDatabase> with _$BeadStockDaoMixin {
  BeadStockDao(super.attachedDatabase);

  SimpleSelectStatement<$BeadStockTable, BeadStockRow> _alive() => select(beadStock)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy(<OrderingTerm Function($BeadStockTable)>[
      (t) => OrderingTerm.asc(t.brand),
      (t) => OrderingTerm.asc(t.code),
      (t) => OrderingTerm.asc(t.id),
    ]);

  Stream<List<BeadStockRow>> watchAlive() => _alive().watch();

  Future<List<BeadStockRow>> alive() => _alive().get();

  /// Живая запись цвета; если по ошибке слияния их несколько — любая, самая свежая.
  Future<BeadStockRow?> findAlive(String brand, String code) =>
      (select(beadStock)
            ..where((t) => t.brand.equals(brand) & t.code.equals(code) & t.deletedAt.isNull())
            ..orderBy(<OrderingTerm Function($BeadStockTable)>[(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<void> insertRow(BeadStockCompanion row) => into(beadStock).insert(row);

  Future<void> updateRow(String id, BeadStockCompanion changes) =>
      (update(beadStock)..where((t) => t.id.equals(id))).write(changes);
}
