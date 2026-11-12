import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/tables/floss_stock_table.dart';
import 'package:drift/drift.dart';

part 'floss_stock_dao.g.dart';

@DriftAccessor(tables: <Type>[FlossStock])
class FlossStockDao extends DatabaseAccessor<AppDatabase> with _$FlossStockDaoMixin {
  FlossStockDao(super.attachedDatabase);

  SimpleSelectStatement<$FlossStockTable, FlossStockRow> _alive() => select(flossStock)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy(<OrderingTerm Function($FlossStockTable)>[
      (t) => OrderingTerm.asc(t.brand),
      (t) => OrderingTerm.asc(t.code),
      (t) => OrderingTerm.asc(t.id),
    ]);

  Stream<List<FlossStockRow>> watchAlive() => _alive().watch();

  Future<List<FlossStockRow>> alive() => _alive().get();

  /// Живая запись нитки; если по ошибке слияния их несколько — любая, самая свежая.
  Future<FlossStockRow?> findAlive(String brand, String code) =>
      (select(flossStock)
            ..where((t) => t.brand.equals(brand) & t.code.equals(code) & t.deletedAt.isNull())
            ..orderBy(<OrderingTerm Function($FlossStockTable)>[(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<void> insertRow(FlossStockCompanion row) => into(flossStock).insert(row);

  Future<void> updateRow(String id, FlossStockCompanion changes) =>
      (update(flossStock)..where((t) => t.id.equals(id))).write(changes);
}
