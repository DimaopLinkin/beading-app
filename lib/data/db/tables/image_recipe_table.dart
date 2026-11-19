import 'package:beading/data/db/tables/projects_table.dart';
import 'package:beading/data/db/tables/sync_columns.dart';
import 'package:drift/drift.dart';

/// Рецепт мастера «Схема из картинки» (T96): параметры и путь исходного фото. `id` равен `id` проекта.
/// Само фото лежит файлом в Application Support и едет на другие устройства через Storage.
@DataClassName('ImageRecipeRow')
class ImageRecipes extends Table with UuidIdColumn, SyncColumns {
  @override
  TextColumn get id => text().references(Projects, #id)();

  /// JSON `ImageRecipeCodec`.
  TextColumn get params => text()();

  /// Относительный путь фото (`recipes/<id проекта>.src`).
  TextColumn get path => text()();
}
