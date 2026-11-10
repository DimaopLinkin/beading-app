import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/catalog/catalog_asset_source.dart';
import 'package:beading/data/catalog/catalog_file_parser.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/catalog_dao.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_file.dart';
import 'package:beading/domain/catalog/code_search_key.dart';
import 'package:drift/drift.dart';

/// Наполняет `catalog_colors` из файлов каталога. Идемпотентно: файл загружается заново, только если его `version`
/// отличается от сохранённой; строки файла заменяются целиком в одной транзакции.
class CatalogSeeder {
  CatalogSeeder({required CatalogDao dao, required CatalogAssetSource assets}) : _dao = dao, _assets = assets;

  final CatalogDao _dao;
  final CatalogAssetSource _assets;

  /// Возвращает первую ошибку, но продолжает загружать остальные файлы: один битый файл не лишает каталога целиком.
  Future<Result<void>> seed() async {
    Failure? firstFailure;
    final List<String> paths;
    try {
      paths = await _assets.listFiles();
    } on Object catch (error) {
      return Err<void>(StorageFailure('Не удалось получить список файлов каталога: $error'));
    }
    for (final String path in paths) {
      final Result<void> result = await _seedFile(path);
      firstFailure ??= result.failureOrNull;
    }
    // Файл убрали или переименовали: его цвета не должны оставаться в каталоге.
    // Пустой список файлов — скорее сбой манифеста, чем «каталог убрали»: ничего не стираем.
    if (paths.isNotEmpty) {
      final Result<void> cleanup = await guardStorage<void>(
        () => _dao.removeSourcesExcept(<String>{for (final String path in paths) catalogFileId(path)}),
      );
      firstFailure ??= cleanup.failureOrNull;
    }
    return firstFailure == null ? const Success<void>(null) : Err<void>(firstFailure);
  }

  Future<Result<void>> _seedFile(String path) async {
    final String id = catalogFileId(path);
    final String text;
    try {
      text = await _assets.read(path);
    } on Object catch (error) {
      return Err<void>(StorageFailure('Каталог $id не прочитан: $error'));
    }
    final Result<CatalogFile> parsed = parseCatalogFile(id, text);
    final CatalogFile? file = parsed.valueOrNull;
    if (file == null) {
      return Err<void>(parsed.failureOrNull!);
    }
    return guardStorage<void>(() async {
      if (await _dao.loadedVersion(id) == file.version) {
        return;
      }
      await _dao.replaceSource(id, file.version, <CatalogColorsCompanion>[
        for (final (int i, CatalogColor c) in file.colors.indexed)
          CatalogColorsCompanion.insert(
            id: '$id|${c.id}',
            source: id,
            material: c.material.wire,
            brand: c.brand,
            series: c.series,
            code: c.code,
            name: c.name,
            rgb: (c.rgb.r << 16) | (c.rgb.g << 8) | c.rgb.b,
            finish: Value<String?>(c.finish),
            sizeCode: Value<String?>(c.sizeCode),
            searchKey: codeSearchKey(c.code),
            position: i,
          ),
      ]);
    });
  }
}
