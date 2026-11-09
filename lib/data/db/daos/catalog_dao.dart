import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/tables/catalog_tables.dart';
import 'package:drift/drift.dart';

part 'catalog_dao.g.dart';

@DriftAccessor(tables: <Type>[CatalogColors, CatalogSources])
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.attachedDatabase);

  Future<int?> loadedVersion(String source) async {
    final CatalogSourceRow? row = await (select(catalogSources)..where((t) => t.id.equals(source))).getSingleOrNull();
    return row?.version;
  }

  /// Заменяет все строки источника одной транзакцией и запоминает версию.
  Future<void> replaceSource(String source, int version, List<CatalogColorsCompanion> rows) => transaction(() async {
    await (delete(catalogColors)..where((t) => t.source.equals(source))).go();
    await batch((b) => b.insertAll(catalogColors, rows));
    await into(catalogSources).insertOnConflictUpdate(CatalogSourcesCompanion.insert(id: source, version: version));
  });

  /// Удаляет строки и версии источников, которых больше нет среди файлов каталога.
  Future<void> removeSourcesExcept(Set<String> keep) => transaction(() async {
    await (delete(catalogColors)..where((t) => t.source.isNotIn(keep))).go();
    await (delete(catalogSources)..where((t) => t.id.isNotIn(keep))).go();
  });

  Future<List<CatalogColorRow>> rows({String? material, String? brand}) {
    final SimpleSelectStatement<$CatalogColorsTable, CatalogColorRow> query = select(catalogColors);
    if (material != null) {
      query.where((t) => t.material.equals(material));
    }
    if (brand != null) {
      query.where((t) => t.brand.equals(brand));
    }
    return query.get();
  }

  Future<List<String>> brandsOf(String material) async {
    final JoinedSelectStatement<$CatalogColorsTable, CatalogColorRow> query = selectOnly(catalogColors, distinct: true)
      ..addColumns(<Expression<Object>>[catalogColors.brand])
      ..where(catalogColors.material.equals(material));
    final List<TypedResult> rows = await query.get();
    return <String>[for (final TypedResult r in rows) r.read(catalogColors.brand)!]..sort();
  }
}
