import 'package:flutter/services.dart';

/// Откуда берутся файлы каталога. В приложении — assets, в тестах — подмена.
abstract interface class CatalogAssetSource {
  /// Пути файлов каталога (`assets/catalog/*.json`) в стабильном порядке.
  Future<List<String>> listFiles();

  Future<String> read(String path);
}

/// Файлы каталога из `AssetBundle`; список берётся из манифеста сборки.
class BundleCatalogAssetSource implements CatalogAssetSource {
  BundleCatalogAssetSource([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  static const String _prefix = 'assets/catalog/';

  final AssetBundle _bundle;

  @override
  Future<List<String>> listFiles() async {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    return manifest.listAssets().where((p) => p.startsWith(_prefix) && p.endsWith('.json')).toList()..sort();
  }

  @override
  Future<String> read(String path) => _bundle.loadString(path);
}

/// Имя файла без каталога и расширения.
String catalogFileId(String path) {
  final String name = path.split('/').last;
  return name.endsWith('.json') ? name.substring(0, name.length - 5) : name;
}
