import 'package:beading/data/db/tables/projects_table.dart';
import 'package:beading/data/db/tables/sync_columns.dart';
import 'package:drift/drift.dart';

/// Сеточная схема проекта (T14). Один проект — одна схема. Сетка — один BLOB (`GridCodec`), а не строка на ячейку.
@DataClassName('GridPatternRow')
class GridPatterns extends Table with UuidIdColumn, SyncColumns {
  TextColumn get projectId => text().references(Projects, #id)();

  /// `rectangular` / `peyote` / `brick`.
  TextColumn get geometry => text()();

  /// Параметр `drop` пейота; у остальных геометрий 1.
  IntColumn get geometryDrop => integer().withDefault(const Constant<int>(1))();

  IntColumn get width => integer()();

  IntColumn get height => integer()();

  /// Размер ячейки: JSON `{"kind": …}` (`CellMetricsCodec`).
  TextColumn get cellMetrics => text()();

  /// Ряд и бусина, на которых остановились. Прогресс по рядам лежит в `grid_progress_rows`.
  IntColumn get currentRow => integer().nullable()();

  IntColumn get currentBead => integer().nullable()();

  BlobColumn get cells => blob()();

  IntColumn get cellsCodecVersion => integer()();

  /// Слои вышивки; пишет и читает T38, до него всегда `NULL`.
  BlobColumn get layers => blob().nullable()();

  IntColumn get layersCodecVersion => integer().nullable()();

  /// Уникальность учитывает и строки с надгробием: схема удалённого проекта не освобождает проект. Если появится
  /// «сброс схемы» без удаления проекта, `save` должен оживлять надгробие.
  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{projectId},
  ];
}

/// Палитра-снимок схемы: значения скопированы из каталога, правка каталога старые схемы не меняет.
@DataClassName('PatternColorRow')
class PatternColors extends Table with UuidIdColumn, SyncColumns {
  TextColumn get gridPatternId => text().references(GridPatterns, #id)();

  /// Номер цвета в палитре с нуля; значение в сетке — `position + 1`.
  IntColumn get position => integer()();

  /// 0xRRGGBB.
  IntColumn get rgb => integer()();

  TextColumn get name => text()();

  /// JSON: список из 1–2 пар `{"brand": …, "code": …}`.
  TextColumn get components => text()();

  TextColumn get finish => text().nullable()();

  TextColumn get symbol => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{gridPatternId, position},
  ];
}

/// Отмеченные ряды схемы. Строка на ряд, чтобы при синхронизации отметки двух устройств объединялись как множество.
/// Снятая отметка — надгробие, повторная — оживляет строку.
@DataClassName('GridProgressRowRecord')
class GridProgressRows extends Table with UuidIdColumn, SyncColumns {
  TextColumn get gridPatternId => text().references(GridPatterns, #id)();

  IntColumn get rowIndex => integer()();

  /// UTC, миллисекунды с эпохи.
  IntColumn get completedAt => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{gridPatternId, rowIndex},
  ];
}

/// Прогресс вышивки по клеткам (T38): битовые блоки 16×16 (`CellProgress`), по 32 байта. Блок без отметок —
/// надгробие. Единица слияния при синхронизации — блок (LWW).
@DataClassName('GridProgressCellRecord')
class GridProgressCells extends Table with UuidIdColumn, SyncColumns {
  TextColumn get gridPatternId => text().references(GridPatterns, #id)();

  /// Индекс блока: `(ряд ~/ 16) * 4096 + столбец ~/ 16`; не зависит от размера схемы.
  IntColumn get blockIndex => integer()();

  /// 32 байта: бит клетки `(ряд % 16) * 16 + столбец % 16`.
  BlobColumn get bits => blob()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{gridPatternId, blockIndex},
  ];
}
