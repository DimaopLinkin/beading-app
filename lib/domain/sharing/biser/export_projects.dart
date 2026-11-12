import 'dart:typed_data';

import 'package:beading/core/clock.dart';
import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/floss_stock/floss_stock_entry.dart';
import 'package:beading/domain/floss_stock/floss_stock_repository.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/domain/grid_pattern/cell_progress_store.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/grid_pattern/grid_progress_store.dart';
import 'package:beading/domain/image_pattern/book_work/book_work_repository.dart';
import 'package:beading/domain/image_pattern/book_work/page_work.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';
import 'package:beading/domain/image_pattern/image_pattern_repository.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/settings/app_info.dart';
import 'package:beading/domain/sharing/biser/biser_codec.dart';
import 'package:beading/domain/sharing/biser/biser_models.dart';
import 'package:beading/domain/weaving/work_session.dart';
import 'package:beading/domain/weaving/work_session_repository.dart';

/// Готовый файл: байты, имя для листа «Поделиться» и число проектов внутри.
final class BiserExport {
  const BiserExport({required this.bytes, required this.fileName, required this.projectCount});

  final Uint8List bytes;
  final String fileName;
  final int projectCount;
}

/// Собирает `.biser` из проектов: один проект («Поделиться») или все (резервная копия).
class ExportProjects {
  const ExportProjects({
    required ProjectRepository projects,
    required GridPatternRepository grids,
    required GridProgressStore progress,
    required CellProgressStore cellProgress,
    required ImagePatternRepository images,
    required BookWorkRepository bookWork,
    required WorkSessionRepository workSessions,
    required FileStore files,
    required BiserCodec codec,
    required Clock clock,
    required AppInfoProvider appInfo,
    FlossStockRepository? flossStock,
  }) : _flossStock = flossStock,
       _projects = projects,
       _grids = grids,
       _progress = progress,
       _cellProgress = cellProgress,
       _images = images,
       _bookWork = bookWork,
       _workSessions = workSessions,
       _files = files,
       _codec = codec,
       _clock = clock,
       _appInfo = appInfo;

  static const String extension = 'biser';

  final ProjectRepository _projects;
  final GridPatternRepository _grids;
  final GridProgressStore _progress;
  final CellProgressStore _cellProgress;
  final ImagePatternRepository _images;
  final BookWorkRepository _bookWork;
  final WorkSessionRepository _workSessions;
  final FileStore _files;
  final BiserCodec _codec;
  final Clock _clock;
  final AppInfoProvider _appInfo;
  final FlossStockRepository? _flossStock;

  /// Один проект.
  Future<Result<BiserExport>> project(String id) async {
    final Result<Project> found = await _projects.get(id);
    if (found case Err<Project>(:final Failure failure)) {
      return Err<BiserExport>(failure);
    }
    final Project project = found.valueOrNull!;
    return _build(<Project>[project], BiserKind.project, _safeName(project.name));
  }

  /// Вся библиотека: резервная копия.
  Future<Result<BiserExport>> backup() async {
    final List<Project> all;
    try {
      all = await _projects.watchAll().first;
    } on Object catch (error) {
      return Err<BiserExport>(StorageFailure('Не удалось прочитать проекты: $error'));
    }
    final DateTime now = _clock.now().toUtc();
    final String date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return _build(all, BiserKind.backup, 'Biser-backup-$date');
  }

  Future<Result<BiserExport>> _build(List<Project> projects, BiserKind kind, String baseName) async {
    final Map<String, Uint8List> files = <String, Uint8List>{};
    final List<BiserProject> items = <BiserProject>[];
    for (final Project project in projects) {
      final Result<BiserProject> item = await _read(project, files);
      if (item case Err<BiserProject>(:final Failure failure)) {
        return Err<BiserExport>(failure);
      }
      final Result<List<WorkSession>> sessions = await _workSessions.byProject(project.id);
      if (sessions case Err<List<WorkSession>>(:final Failure failure)) {
        return Err<BiserExport>(failure);
      }
      items.add(item.valueOrNull!.withWorkSessions(sessions.valueOrNull!));
    }
    // Запас ниток общий для проектов: в файл он попадает только с резервной копией библиотеки.
    List<FlossStockEntry> stock = const <FlossStockEntry>[];
    if (kind == BiserKind.backup && _flossStock != null) {
      final Result<List<FlossStockEntry>> loaded = await _flossStock.all();
      if (loaded case Err<List<FlossStockEntry>>(:final Failure failure)) {
        return Err<BiserExport>(failure);
      }
      stock = loaded.valueOrNull!;
    }
    final AppInfo info = await _appInfo.load();
    final Result<Uint8List> bytes = _codec.encode(
      BiserBundle(
        kind: kind,
        exportedAt: _clock.now().toUtc(),
        appVersion: info.version,
        projects: items,
        files: files,
        flossStock: stock,
      ),
    );
    return bytes.map((b) => BiserExport(bytes: b, fileName: '$baseName.$extension', projectCount: items.length));
  }

  Future<Result<BiserProject>> _read(Project project, Map<String, Uint8List> files) async {
    switch (project.contentKind) {
      case ContentKind.grid:
        final Result<GridPattern> grid = await _grids.getByProject(project.id);
        if (grid case Err<GridPattern>(:final Failure failure)) {
          // Проект без схемы (запись не удалась до конца) уезжает пустым.
          return failure is NotFoundFailure ? Success<BiserProject>(BiserProject(project: project)) : Err(failure);
        }
        final GridPattern pattern = grid.valueOrNull!;
        final Result<GridProgress> progress = await _progress.load(pattern.id);
        if (progress case Err<GridProgress>(:final Failure failure)) {
          return Err<BiserProject>(failure);
        }
        final Result<CellProgress> cells = await _cellProgress.load(pattern.id);
        if (cells case Err<CellProgress>(:final Failure failure)) {
          return Err<BiserProject>(failure);
        }
        return Success<BiserProject>(
          BiserProject(project: project, grid: pattern, progress: progress.valueOrNull, cells: cells.valueOrNull),
        );
      case ContentKind.image:
        final Result<ImagePattern> found = await _images.getByProject(project.id);
        if (found case Err<ImagePattern>(:final Failure failure)) {
          return failure is NotFoundFailure ? Success<BiserProject>(BiserProject(project: project)) : Err(failure);
        }
        final ImagePattern pattern = found.valueOrNull!;
        final Result<BookWork> work = await _bookWork.load(pattern.id);
        if (work case Err<BookWork>(:final Failure failure)) {
          return Err<BiserProject>(failure);
        }
        final BookWork bookWork = work.valueOrNull!;
        final List<BiserPage> pages = <BiserPage>[];
        String? coverPageId;
        for (final ImagePatternPage page in pattern.pages) {
          final Result<Uint8List> bytes = await _files.read(page.path);
          if (bytes case Err<Uint8List>(:final Failure failure)) {
            return Err<BiserProject>(failure);
          }
          final String file = 'images/${page.id}.png';
          files[file] = bytes.valueOrNull!;
          pages.add(
            BiserPage(id: page.id, file: file, width: page.width, height: page.height, work: bookWork.pages[page.id]),
          );
          if (page.path == project.coverPath) {
            coverPageId = page.id;
          }
        }
        return Success<BiserProject>(
          BiserProject(
            project: project,
            book: BiserBook(patternId: pattern.id, pages: pages, currentPageId: bookWork.currentPageId),
            coverPageId: coverPageId,
          ),
        );
      case ContentKind.steps:
        return Success<BiserProject>(BiserProject(project: project));
    }
  }

  /// Имя файла из названия проекта: без символов, недопустимых в путях.
  static String _safeName(String name) {
    final String cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final String limited = String.fromCharCodes(cleaned.runes.take(60)).trim();
    return limited.isEmpty ? 'Biser-project' : limited;
  }
}
