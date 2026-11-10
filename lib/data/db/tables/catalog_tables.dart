import 'package:drift/drift.dart';

/// Каталог цветов бисера и ниток. Наполняется из `assets/catalog/*.json`, не синхронизируется,
/// поэтому без служебных колонок синхронизации.
@DataClassName('CatalogColorRow')
class CatalogColors extends Table {
  /// `CatalogColor.id`.
  TextColumn get id => text()();

  /// Файл-источник (`CatalogFile.id`); по нему строки пересоздаются при смене версии файла.
  TextColumn get source => text()();

  /// `bead` или `floss`.
  TextColumn get material => text()();

  TextColumn get brand => text()();

  TextColumn get series => text()();

  TextColumn get code => text()();

  TextColumn get name => text()();

  /// 0xRRGGBB.
  IntColumn get rgb => integer()();

  TextColumn get finish => text().nullable()();

  TextColumn get sizeCode => text().nullable()();

  /// `codeSearchKey(code)`.
  TextColumn get searchKey => text()();

  /// Порядок внутри файла: каталожный порядок сохраняем.
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Какая версия каждого файла каталога уже загружена.
@DataClassName('CatalogSourceRow')
class CatalogSources extends Table {
  TextColumn get id => text()();

  IntColumn get version => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
