import 'package:beading/data/db/tables/projects_table.dart';
import 'package:beading/data/db/tables/sync_columns.dart';
import 'package:drift/drift.dart';

/// Схема-картинка проекта (T06). Один проект — одна схема.
@DataClassName('ImagePatternRow')
class ImagePatterns extends Table with UuidIdColumn, SyncColumns {
  TextColumn get projectId => text().references(Projects, #id)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{projectId},
  ];
}

/// Страницы схемы по порядку. Файл лежит в Application Support, здесь только относительный путь.
@DataClassName('ImagePatternPageRow')
class ImagePatternPages extends Table with UuidIdColumn, SyncColumns {
  TextColumn get patternId => text().references(ImagePatterns, #id)();

  /// Порядковый номер страницы с нуля.
  IntColumn get position => integer()();

  TextColumn get path => text()();

  IntColumn get width => integer()();

  IntColumn get height => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{patternId, position},
  ];
}
