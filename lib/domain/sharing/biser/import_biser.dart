import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/grid_pattern/grid_progress_store.dart';
import 'package:beading/domain/image_pattern/book_work/book_work_repository.dart';
import 'package:beading/domain/image_pattern/book_work/page_work.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';
import 'package:beading/domain/image_pattern/image_pattern_paths.dart';
import 'package:beading/domain/image_pattern/image_pattern_repository.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/sharing/biser/biser_codec.dart';
import 'package:beading/domain/sharing/biser/biser_models.dart';
import 'package:beading/domain/sharing/unit_of_work.dart';
import 'package:equatable/equatable.dart';

/// Что делать с проектом файла, id которого уже есть в библиотеке.
enum ConflictChoice {
  /// Добавить копией с новыми id; существующий проект не трогаем.
  asNew,

  /// Не импортировать.
  skip,
}

/// Проект файла в обзоре перед импортом.
final class BiserPreviewItem extends Equatable {
  const BiserPreviewItem({
    required this.id,
    required this.name,
    required this.craft,
    required this.contentKind,
    required this.exists,
  });

  final String id;
  final String name;
  final Craft craft;
  final ContentKind contentKind;

  /// Проект с таким id уже есть в библиотеке.
  final bool exists;

  @override
  List<Object?> get props => <Object?>[id, name, craft, contentKind, exists];
}

final class BiserPreview extends Equatable {
  BiserPreview({required this.kind, required List<BiserPreviewItem> items})
    : items = List<BiserPreviewItem>.unmodifiable(items);

  final BiserKind kind;
  final List<BiserPreviewItem> items;

  int get conflictCount => items.where((i) => i.exists).length;

  @override
  List<Object?> get props => <Object?>[kind, items];
}

/// Итог импорта: id созданных проектов (в порядке файла) и число пропущенных.
final class ImportResult extends Equatable {
  ImportResult({required List<String> importedIds, required this.skipped})
    : importedIds = List<String>.unmodifiable(importedIds);

  final List<String> importedIds;
  final int skipped;

  @override
  List<Object?> get props => <Object?>[importedIds, skipped];
}

/// Импорт `.biser`. Файл сначала целиком разбирается и проверяется, потом всё пишется одной транзакцией:
/// ошибка на любом шаге откатывает базу и убирает записанные файлы.
class ImportBiser {
  const ImportBiser({
    required BiserCodec codec,
    required ProjectRepository projects,
    required GridPatternRepository grids,
    required GridProgressStore progress,
    required ImagePatternRepository images,
    required BookWorkRepository bookWork,
    required FileStore files,
    required IdGenerator ids,
    required UnitOfWork unitOfWork,
  }) : _codec = codec,
       _projects = projects,
       _grids = grids,
       _progress = progress,
       _images = images,
       _bookWork = bookWork,
       _files = files,
       _ids = ids,
       _unitOfWork = unitOfWork;

  final BiserCodec _codec;
  final ProjectRepository _projects;
  final GridPatternRepository _grids;
  final GridProgressStore _progress;
  final ImagePatternRepository _images;
  final BookWorkRepository _bookWork;
  final FileStore _files;
  final IdGenerator _ids;
  final UnitOfWork _unitOfWork;

  /// Читает файл и показывает, что в нём, ничего не записывая.
  Future<Result<BiserPreview>> preview(Uint8List bytes) async {
    final Result<BiserBundle> decoded = _codec.decode(bytes);
    if (decoded case Err<BiserBundle>(:final Failure failure)) {
      return Err<BiserPreview>(failure);
    }
    final BiserBundle bundle = decoded.valueOrNull!;
    final List<BiserPreviewItem> items = <BiserPreviewItem>[];
    for (final BiserProject item in bundle.projects) {
      final Project p = item.project;
      items.add(
        BiserPreviewItem(
          id: p.id,
          name: p.name,
          craft: p.craft,
          contentKind: p.contentKind,
          exists: await _exists(p.id),
        ),
      );
    }
    return Success<BiserPreview>(BiserPreview(kind: bundle.kind, items: items));
  }

  /// Импортирует файл. [choices] — выбор по id проекта; для совпавших без выбора действует [defaultChoice].
  Future<Result<ImportResult>> call(
    Uint8List bytes, {
    Map<String, ConflictChoice> choices = const <String, ConflictChoice>{},
    ConflictChoice defaultChoice = ConflictChoice.asNew,
  }) async {
    final Result<BiserBundle> decoded = _codec.decode(bytes);
    if (decoded case Err<BiserBundle>(:final Failure failure)) {
      return Err<ImportResult>(failure);
    }
    final BiserBundle bundle = decoded.valueOrNull!;
    final List<String> written = <String>[];
    Result<ImportResult> result;
    try {
      result = await _unitOfWork.run<ImportResult>(() async {
        final List<String> imported = <String>[];
        int skipped = 0;
        for (final BiserProject item in bundle.projects) {
          final bool exists = await _exists(item.project.id);
          if (exists && (choices[item.project.id] ?? defaultChoice) == ConflictChoice.skip) {
            skipped++;
            continue;
          }
          final Result<String> id = await _importOne(item, bundle.files, fresh: exists, written: written);
          if (id case Err<String>(:final Failure failure)) {
            return Err<ImportResult>(failure);
          }
          imported.add(id.valueOrNull!);
        }
        return Success<ImportResult>(ImportResult(importedIds: imported, skipped: skipped));
      });
    } on Object catch (error) {
      result = Err<ImportResult>(UnexpectedFailure('Импорт не удался: $error'));
    }
    if (result case Err<ImportResult>()) {
      for (final String path in written) {
        await _files.delete(path);
      }
    }
    return result;
  }

  Future<bool> _exists(String id) async => (await _projects.get(id)).isSuccess;

  Future<Result<String>> _importOne(
    BiserProject item,
    Map<String, Uint8List> files, {
    required bool fresh,
    required List<String> written,
  }) async {
    // Совпавший id — только новые id. Проект, удалённый раньше, по id не восстановить: тоже копия.
    final Result<String> first = await _write(item, files, fresh: fresh, written: written);
    if (first case Err<String>(failure: NotFoundFailure()) when !fresh) {
      return _write(item, files, fresh: true, written: written);
    }
    return first;
  }

  Future<Result<String>> _write(
    BiserProject item,
    Map<String, Uint8List> files, {
    required bool fresh,
    required List<String> written,
  }) async {
    String idFor(String original) => fresh ? _ids.next() : original;
    final String projectId = idFor(item.project.id);
    final BiserBook? book = item.book;
    final String? bookId = book == null ? null : idFor(book.patternId);
    final Map<String, String> pageIds = <String, String>{
      if (book != null)
        for (final BiserPage page in book.pages) page.id: idFor(page.id),
    };
    String pagePath(String pageId) => imagePatternPagePath(patternId: bookId!, pageId: pageIds[pageId]!);

    final Project project = Project(
      id: projectId,
      name: item.project.name,
      status: item.project.status,
      craft: item.project.craft,
      technique: item.project.technique,
      contentKind: item.project.contentKind,
      notes: item.project.notes,
      coverPath: item.coverPageId == null ? null : pagePath(item.coverPageId!),
      lastWorkedAt: item.project.lastWorkedAt,
    );
    final Result<void> saved = await _projects.save(project);
    if (saved case Err<void>(:final Failure failure)) {
      return Err<String>(failure);
    }

    final GridPattern? grid = item.grid;
    if (grid != null) {
      final GridPattern pattern = grid.withIds(id: idFor(grid.id), projectId: projectId);
      final Result<void> gridSaved = await _grids.save(pattern);
      if (gridSaved case Err<void>(:final Failure failure)) {
        return Err<String>(failure);
      }
      final GridProgress? progress = item.progress;
      if (progress != null) {
        for (final int row in progress.completedRows.toList()..sort()) {
          final Result<void> marked = await _progress.markRow(pattern.id, row);
          if (marked case Err<void>(:final Failure failure)) {
            return Err<String>(failure);
          }
        }
        final int? row = progress.currentRow;
        if (row != null) {
          final Result<void> current = await _progress.setCurrent(pattern.id, row: row, bead: progress.currentBead);
          if (current case Err<void>(:final Failure failure)) {
            return Err<String>(failure);
          }
        }
      }
    }

    if (book != null) {
      final List<ImagePatternPage> pages = <ImagePatternPage>[];
      for (final BiserPage page in book.pages) {
        final String path = pagePath(page.id);
        final Result<void> wrote = await _files.write(path, files[page.file]!);
        if (wrote case Err<void>(:final Failure failure)) {
          return Err<String>(failure);
        }
        written.add(path);
        pages.add(ImagePatternPage(id: pageIds[page.id]!, path: path, width: page.width, height: page.height));
      }
      final Result<void> patternSaved = await _images.save(
        ImagePattern(id: bookId!, projectId: projectId, pages: pages),
      );
      if (patternSaved case Err<void>(:final Failure failure)) {
        return Err<String>(failure);
      }
      for (final BiserPage page in book.pages) {
        final PageWork? work = page.work;
        if (work == null) {
          continue;
        }
        final Result<void> workSaved = await _bookWork.savePage(
          PageWork(pageId: pageIds[page.id]!, ruler: work.ruler, viewport: work.viewport),
        );
        if (workSaved case Err<void>(:final Failure failure)) {
          return Err<String>(failure);
        }
      }
      final String? current = book.currentPageId;
      if (current != null) {
        final Result<void> currentSaved = await _bookWork.saveCurrentPage(patternId: bookId, pageId: pageIds[current]!);
        if (currentSaved case Err<void>(:final Failure failure)) {
          return Err<String>(failure);
        }
      }
    }
    return Success<String>(projectId);
  }
}
