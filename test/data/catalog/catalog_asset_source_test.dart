import 'package:beading/data/catalog/catalog_asset_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalogFileId отбрасывает путь и расширение', () {
    expect(catalogFileId('assets/catalog/toho_round_11.json'), 'toho_round_11');
    expect(catalogFileId('plain'), 'plain');
  });

  test('BundleCatalogAssetSource видит файлы из assets/catalog', () async {
    final BundleCatalogAssetSource source = BundleCatalogAssetSource();
    final List<String> files = await source.listFiles();
    expect(files, contains('assets/catalog/toho_round_11.json'));
    expect(files.every((p) => p.endsWith('.json')), isTrue);
    expect(await source.read(files.first), contains('"colors"'));
  });
}
