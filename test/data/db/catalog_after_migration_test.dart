import 'package:beading/data/catalog/catalog_seeder.dart';
import 'package:beading/data/catalog/drift_catalog_repository.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../catalog/fake_catalog_assets.dart';
import 'migration/app_database/generated/schema.dart';

/// Каталог работает на базе, обновлённой с v1 (у пользовательницы до T13 была v1).
void main() {
  test('после миграции v1 → v5 каталог наполняется и ищется', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(1);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);

    await CatalogSeeder(
      dao: db.catalogDao,
      assets: FakeCatalogAssets(<String, String>{
        'assets/catalog/a.json': catalogJson(colors: <(String, String, String)>[('DB0010', 'Black', '#111111')]),
      }),
    ).seed();
    expect((await DriftCatalogRepository(db.catalogDao).search(query: 'db10')).valueOrNull, hasLength(1));
  });
}
