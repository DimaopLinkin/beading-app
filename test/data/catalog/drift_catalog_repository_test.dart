import 'package:beading/core/result.dart';
import 'package:beading/data/catalog/catalog_seeder.dart';
import 'package:beading/data/catalog/drift_catalog_repository.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_database.dart';
import 'fake_catalog_assets.dart';

void main() {
  late DriftCatalogRepository repo;

  setUp(() async {
    final db = createInMemoryDatabase();
    await CatalogSeeder(
      dao: db.catalogDao,
      assets: FakeCatalogAssets(<String, String>{
        'assets/catalog/delica.json': catalogJson(
          colors: <(String, String, String)>[
            ('DB0100', 'Opaque Red', '#cc0000'),
            ('DB0010', 'Metallic Silver', '#c0c0c0'),
            ('DB0002', 'Matte Black', '#202020'),
            ('DB1010', 'Light Blue', '#99ccff'),
          ],
        ),
        'assets/catalog/toho.json': catalogJson(
          brand: 'Toho',
          series: 'Round',
          colors: <(String, String, String)>[('49', 'Opaque Jet', '#111111'), ('45A', 'Ёлочный зелёный', '#228b22')],
        ),
        'assets/catalog/dmc.json': catalogJson(
          material: 'floss',
          brand: 'DMC',
          series: 'Mouliné',
          sizeCode: null,
          colors: <(String, String, String)>[('310', 'Black', '#000000')],
        ),
      }),
    ).seed();
    repo = DriftCatalogRepository(db.catalogDao);
  });

  Future<List<String>> codes(Future<Result<List<CatalogColor>>> result) async =>
      (await result).valueOrNull!.map((c) => c.code).toList();

  test('«10», «DB-0010» и «db10» находят одно и то же', () async {
    final List<String> a = await codes(repo.search(query: '10'));
    final List<String> b = await codes(repo.search(query: 'DB-0010'));
    final List<String> c = await codes(repo.search(query: 'db10'));
    expect(a, <String>['DB0010']);
    expect(b, a);
    expect(c, a);
  });

  test('номер без буквы на конце находит артикул с буквой отделки', () async {
    expect(await codes(repo.search(query: '45')), <String>['45A']);
    expect(await codes(repo.search(query: '49')), <String>['49']);
  });

  test('очень длинный номер не ломает сортировку', () async {
    final db = createInMemoryDatabase();
    await CatalogSeeder(
      dao: db.catalogDao,
      assets: FakeCatalogAssets(<String, String>{
        'assets/catalog/x.json': catalogJson(
          colors: <(String, String, String)>[('X99999999999999999999999', 'A', '#000000'), ('X1', 'B', '#000000')],
        ),
      }),
    ).seed();
    final r = await DriftCatalogRepository(db.catalogDao).search();
    expect(r.valueOrNull!.map((c) => c.code), <String>['X1', 'X99999999999999999999999']);
  });

  test('строка с неизвестным материалом пропускается', () async {
    final db = createInMemoryDatabase();
    await db.customStatement(
      'INSERT INTO catalog_colors (id, source, material, brand, series, code, name, rgb, search_key, position) '
      "VALUES ('x', 's', 'wood', 'B', 'S', '1', 'n', 0, '1', 0)",
    );
    expect((await DriftCatalogRepository(db.catalogDao).search()).valueOrNull, isEmpty);
  });

  test('count <= 0 — пустой список', () async {
    expect((await repo.nearest(const Rgb(1, 1, 1), material: CatalogMaterial.bead, count: 0)).valueOrNull, isEmpty);
  });

  test('поиск по названию без учёта регистра и ё/е', () async {
    expect(await codes(repo.search(query: 'JET')), <String>['49']);
    expect(await codes(repo.search(query: 'елочный')), <String>['45A']);
    expect(await codes(repo.search(query: 'opaque red')), <String>['DB0100']);
  });

  test('пустой запрос: всё, порядок бренд → артикул как число', () async {
    expect(await codes(repo.search(material: CatalogMaterial.bead)), <String>[
      'DB0002',
      'DB0010',
      'DB0100',
      'DB1010',
      '45A',
      '49',
    ]);
  });

  test('фильтры по материалу и бренду', () async {
    expect(await codes(repo.search(material: CatalogMaterial.floss)), <String>['310']);
    expect(await codes(repo.search(brand: 'Toho')), <String>['45A', '49']);
    expect(await codes(repo.search(query: 'black', brand: 'Toho')), isEmpty);
  });

  test('бренды материала', () async {
    expect((await repo.brands(CatalogMaterial.bead)).valueOrNull, <String>['Miyuki', 'Toho']);
    expect((await repo.brands(CatalogMaterial.floss)).valueOrNull, <String>['DMC']);
  });

  test('find по бренду и артикулу в любой записи', () async {
    expect((await repo.find('Miyuki', 'db-100')).valueOrNull?.name, 'Opaque Red');
    expect((await repo.find('Miyuki', 'nope')).valueOrNull, isNull);
  });

  test('ближайшие по ΔE с фильтром по материалу', () async {
    final matches = (await repo.nearest(const Rgb(250, 0, 0), material: CatalogMaterial.bead, count: 2)).valueOrNull!;
    expect(matches.first.item.code, 'DB0100');
    expect(matches, hasLength(2));
    final floss = (await repo.nearest(const Rgb(250, 0, 0), material: CatalogMaterial.floss)).valueOrNull!;
    expect(floss.single.item.code, '310');
    final brand = (await repo.nearest(const Rgb(0, 0, 0), material: CatalogMaterial.bead, brand: 'Toho')).valueOrNull!;
    expect(brand.first.item.code, '49');
  });
}
