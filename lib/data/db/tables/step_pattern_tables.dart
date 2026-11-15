import 'package:beading/data/db/tables/projects_table.dart';
import 'package:beading/data/db/tables/sync_columns.dart';
import 'package:drift/drift.dart';

/// Пошаговая инструкция проекта (T33a, ADR-0008). Один проект — одна инструкция; вся структура (секции,
/// шаги, палитра) лежит одним JSON-документом в [body].
@DataClassName('StepPatternRow')
class StepPatterns extends Table with UuidIdColumn, SyncColumns {
  TextColumn get projectId => text().references(Projects, #id)();

  /// Документ `StepPatternCodec`.
  TextColumn get body => text()();

  /// Версия формата документа; вне записи, чтобы старое приложение отличало новый документ, не разбирая его.
  IntColumn get bodyVersion => integer()();

  /// Встроенный шаблон, из которого создана инструкция.
  TextColumn get templateId => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{projectId},
  ];
}

/// Картинки шагов. Файл лежит в Application Support, здесь только относительный путь.
@DataClassName('StepImageRow')
class StepImages extends Table with UuidIdColumn, SyncColumns {
  TextColumn get patternId => text().references(StepPatterns, #id)();

  TextColumn get path => text()();

  IntColumn get width => integer()();

  IntColumn get height => integer()();
}

/// Курсор прогресса: одна запись на инструкцию, `id` равен `id` инструкции.
@DataClassName('StepProgressRow')
class StepProgressRows extends Table with UuidIdColumn, SyncColumns {
  @override
  TextColumn get id => text().references(StepPatterns, #id)();

  @override
  String get tableName => 'step_progress';

  TextColumn get sectionId => text()();

  IntColumn get sectionPass => integer()();

  TextColumn get stepId => text()();

  IntColumn get stepPass => integer()();

  BoolColumn get finished => boolean()();
}
