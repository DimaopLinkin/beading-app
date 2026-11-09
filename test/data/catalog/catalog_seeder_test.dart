import 'package:beading/core/result.dart';
import 'package:beading/data/catalog/catalog_asset_source.dart';
import 'package:beading/data/catalog/catalog_seeder.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_database.dart';
import 'fake_catalog_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() => db = createInMemoryDatabase());

  CatalogSeeder seederFor(Map<String, String> files) =>
      CatalogSeeder(dao: db.catalogDao, assets: FakeCatalogAssets(files));

  Future<int> count() async => (await db.catalogDao.rows()).length;

  const List<(String, String, String)> two = <(String, String, String)>[
    ('DB0010', 'Black', '#111111'),
    ('DB0011', 'Red', '#ff0000'),
  ];

  test('первое наполнение записывает строки', () async {
    final Result<void> r = await seederFor(<String, String>{'assets/catalog/a.json': catalogJson(colors: two)}).seed();
    expect(r.isSuccess, isTrue);
    expect(await count(), 2);
  });

  test('повторное наполнение не дублирует строки', () async {
    final CatalogSeeder seeder = seederFor(<String, String>{'assets/catalog/a.json': catalogJson(colors: two)});
    await seeder.seed();
    await seeder.seed();
    expect(await count(), 2);
  });

  test('новая версия файла заменяет строки целиком', () async {
    await seederFor(<String, String>{'assets/catalog/a.json': catalogJson(colors: two)}).seed();
    await seederFor(<String, String>{
      'assets/catalog/a.json': catalogJson(
        version: 2,
        colors: <(String, String, String)>[('DB0010', 'Jet Black', '#000000')],
      ),
    }).seed();
    final rows = await db.catalogDao.rows();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Jet Black');
    expect(await db.catalogDao.loadedVersion('a'), 2);
  });

  test('та же версия с другим содержимым не перечитывается', () async {
    await seederFor(<String, String>{'assets/catalog/a.json': catalogJson(colors: two)}).seed();
    await seederFor(<String, String>{
      'assets/catalog/a.json': catalogJson(colors: <(String, String, String)>[('DB0099', 'X', '#000000')]),
    }).seed();
    expect(await count(), 2);
  });

  test('убранный из assets файл исчезает из каталога', () async {
    await seederFor(<String, String>{
      'assets/catalog/a.json': catalogJson(colors: two),
      'assets/catalog/b.json': catalogJson(brand: 'Toho', colors: two),
    }).seed();
    expect(await count(), 4);
    await seederFor(<String, String>{'assets/catalog/a.json': catalogJson(colors: two)}).seed();
    expect(await count(), 2);
    expect(await db.catalogDao.loadedVersion('b'), isNull);
  });

  test('пустой список файлов не стирает каталог', () async {
    await seederFor(<String, String>{'assets/catalog/a.json': catalogJson(colors: two)}).seed();
    expect((await seederFor(<String, String>{}).seed()).isSuccess, isTrue);
    expect(await count(), 2);
  });

  test('два файла с одним брендом, серией и размером не конфликтуют', () async {
    final Result<void> r = await seederFor(<String, String>{
      'assets/catalog/a.json': catalogJson(colors: two),
      'assets/catalog/b.json': catalogJson(colors: two),
    }).seed();
    expect(r.isSuccess, isTrue);
    expect(await count(), 4);
  });

  test('битый файл даёт ошибку, остальные файлы загружаются', () async {
    final Result<void> r = await seederFor(<String, String>{
      'assets/catalog/a.json': '{oops',
      'assets/catalog/b.json': catalogJson(colors: two),
    }).seed();
    expect(r.isFailure, isTrue);
    expect(await count(), 2);
    expect(await db.catalogDao.loadedVersion('a'), isNull);
  });

  test('настоящие файлы приложения загружаются и повторно не дублируются', () async {
    final CatalogSeeder seeder = CatalogSeeder(dao: db.catalogDao, assets: BundleCatalogAssetSource());
    expect((await seeder.seed()).failureOrNull, isNull);
    final int first = await count();
    expect(first, greaterThan(50));
    await seeder.seed();
    expect(await count(), first);
  });

  test('ошибка чтения файла — StorageFailure', () async {
    final Result<void> r = await CatalogSeeder(dao: db.catalogDao, assets: _Broken()).seed();
    expect(r.isFailure, isTrue);
  });
}

class _Broken extends FakeCatalogAssets {
  _Broken() : super(<String, String>{});

  @override
  Future<List<String>> listFiles() async => <String>['assets/catalog/x.json'];

  @override
  Future<String> read(String path) async => throw StateError('boom');
}
