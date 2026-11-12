import 'dart:typed_data';

import 'package:beading/domain/floss_stock/floss_stock_entry.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/image_pattern/book_work/page_work.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/weaving/work_session.dart';
import 'package:equatable/equatable.dart';

/// Версия формата `.biser`, которую пишет это приложение. Файл новее — понятная ошибка, а не порча данных.
/// Версия 2 добавила отметки клеток вышивки (`progress.cellBlocks`), версия 3 — запас ниток (`flossStock`); файлы
/// прежних версий читаются по-прежнему.
const int biserFormatVersion = 3;

/// Что лежит в файле: один проект или резервная копия всей библиотеки.
enum BiserKind { project, backup }

/// Страница схемы из книги. [file] — путь картинки внутри архива.
final class BiserPage extends Equatable {
  const BiserPage({required this.id, required this.file, required this.width, required this.height, this.work});

  final String id;
  final String file;
  final int width;
  final int height;

  /// Линейка и вид страницы; `null`, если на странице ещё не работали.
  final PageWork? work;

  @override
  List<Object?> get props => <Object?>[id, file, width, height, work];
}

/// Схема из книги: страницы и открытая страница.
final class BiserBook extends Equatable {
  BiserBook({required this.patternId, required List<BiserPage> pages, this.currentPageId})
    : pages = List<BiserPage>.unmodifiable(pages);

  final String patternId;
  final List<BiserPage> pages;
  final String? currentPageId;

  @override
  List<Object?> get props => <Object?>[patternId, pages, currentPageId];
}

/// Проект со всем содержимым. `coverPath` проекта в файле не хранится: обложкой служит страница [coverPageId].
final class BiserProject extends Equatable {
  const BiserProject({
    required this.project,
    this.grid,
    this.progress,
    this.cells,
    this.book,
    this.coverPageId,
    this.workSessions = const <WorkSession>[],
  });

  final Project project;
  final GridPattern? grid;
  final GridProgress? progress;

  /// Отметки клеток вышивки; `null` или пусто, если не отмечено ни одной.
  final CellProgress? cells;
  final BiserBook? book;
  final String? coverPageId;

  /// Сессии работы над проектом: из них складывается учтённое время. Ключи id и projectId в файле не хранятся.
  final List<WorkSession> workSessions;

  BiserProject withWorkSessions(List<WorkSession> sessions) => BiserProject(
    project: project,
    grid: grid,
    progress: progress,
    cells: cells,
    book: book,
    coverPageId: coverPageId,
    workSessions: List<WorkSession>.unmodifiable(sessions),
  );

  @override
  List<Object?> get props => <Object?>[project, grid, progress, cells, book, coverPageId, workSessions];
}

/// Всё содержимое файла `.biser`: манифест и файлы (картинки страниц) по путям внутри архива.
final class BiserBundle extends Equatable {
  BiserBundle({
    required this.kind,
    required this.exportedAt,
    required this.appVersion,
    required List<BiserProject> projects,
    Map<String, Uint8List> files = const <String, Uint8List>{},
    List<FlossStockEntry> flossStock = const <FlossStockEntry>[],
    int? formatVersion,
  }) : formatVersion =
           formatVersion ??
           (flossStock.isNotEmpty ? 3 : (projects.any((p) => p.cells != null && !p.cells!.isEmpty) ? 2 : 1)),
       flossStock = List<FlossStockEntry>.unmodifiable(flossStock),
       projects = List<BiserProject>.unmodifiable(projects),
       files = Map<String, Uint8List>.unmodifiable(files);

  /// Версия формата. По умолчанию — наименьшая, которой хватает содержимому: 3 только при запасе ниток, 2 только при
  /// отметках клеток, иначе файл остаётся читаемым приложением, которое знает лишь версию 1.
  final int formatVersion;
  final BiserKind kind;
  final DateTime exportedAt;
  final String appVersion;
  final List<BiserProject> projects;
  final Map<String, Uint8List> files;

  /// Запас ниток мулине (резервная копия); у каждой записи есть `updatedAt`.
  final List<FlossStockEntry> flossStock;

  @override
  List<Object?> get props => <Object?>[formatVersion, kind, exportedAt, appVersion, projects, files, flossStock];
}
