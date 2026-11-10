import 'package:beading/data/catalog/catalog_asset_source.dart';

/// Файлы каталога из памяти.
class FakeCatalogAssets implements CatalogAssetSource {
  FakeCatalogAssets(this.files);

  final Map<String, String> files;

  @override
  Future<List<String>> listFiles() async => files.keys.toList()..sort();

  @override
  Future<String> read(String path) async => files[path] ?? (throw StateError('нет файла $path'));
}

String catalogJson({
  int version = 1,
  String material = 'bead',
  String brand = 'Miyuki',
  String series = 'Delica',
  String? sizeCode = '11/0',
  required List<(String, String, String)> colors,
}) =>
    '{"version":$version,"material":"$material","brand":"$brand","series":"$series",'
    '${sizeCode == null ? '' : '"sizeCode":"$sizeCode",'}"colors":['
    '${colors.map(((String, String, String) c) => '{"code":"${c.$1}","name":"${c.$2}","rgb":"${c.$3}"}').join(',')}]}';
