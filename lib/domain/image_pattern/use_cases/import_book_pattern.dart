import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';
import 'package:beading/domain/image_pattern/image_pattern_paths.dart';
import 'package:beading/domain/image_pattern/image_pattern_repository.dart';
import 'package:beading/domain/image_pattern/image_processor.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';

/// Одна страница на входе импорта: исходные байты и правки пользователя.
class BookPageSource {
  const BookPageSource({required this.bytes, this.quarterTurns = 0, this.crop = CropRect.full});

  final Uint8List bytes;
  final int quarterTurns;
  final CropRect crop;
}

/// Создаёт проект с `contentKind = image` из страниц книги: приводит каждую к PNG, кладёт в хранилище приложения,
/// записывает схему. При любой ошибке не оставляет ни проекта, ни файлов.
class ImportBookPattern {
  const ImportBookPattern({
    required CreateProject createProject,
    required ProjectRepository projects,
    required ImagePatternRepository patterns,
    required ImageProcessor processor,
    required FileStore files,
    required IdGenerator ids,
  }) : _createProject = createProject,
       _projects = projects,
       _patterns = patterns,
       _processor = processor,
       _files = files,
       _ids = ids;

  final CreateProject _createProject;
  final ProjectRepository _projects;
  final ImagePatternRepository _patterns;
  final ImageProcessor _processor;
  final FileStore _files;
  final IdGenerator _ids;

  Future<Result<Project>> call({
    required String name,
    required List<BookPageSource> pages,
    Craft craft = Craft.beading,
    Technique? technique,
  }) async {
    if (pages.isEmpty) {
      return const Err<Project>(ValidationFailure('Нужна хотя бы одна страница'));
    }
    final List<ProcessedImage> processed = <ProcessedImage>[];
    for (final BookPageSource page in pages) {
      final Result<ProcessedImage> result = await _processor.process(
        page.bytes,
        quarterTurns: page.quarterTurns,
        crop: page.crop,
      );
      switch (result) {
        case Success<ProcessedImage>(:final ProcessedImage value):
          processed.add(value);
        case Err<ProcessedImage>(:final Failure failure):
          return Err<Project>(failure);
      }
    }

    final String patternId = _ids.next();
    final List<ImagePatternPage> storedPages = <ImagePatternPage>[];
    for (final ProcessedImage image in processed) {
      final String pageId = _ids.next();
      final String path = imagePatternPagePath(patternId: patternId, pageId: pageId);
      final Result<void> written = await _files.write(path, image.png);
      if (written case Err<void>(:final Failure failure)) {
        await _removeFiles(storedPages);
        return Err<Project>(failure);
      }
      storedPages.add(ImagePatternPage(id: pageId, path: path, width: image.width, height: image.height));
    }

    final Result<Project> created = await _createProject(
      name: name,
      craft: craft,
      technique: technique,
      coverPath: storedPages.first.path,
    );
    if (created case Err<Project>()) {
      await _removeFiles(storedPages);
      return created;
    }
    final Project project = created.valueOrNull!;
    final Result<void> saved = await _patterns.save(
      ImagePattern(id: patternId, projectId: project.id, pages: storedPages),
    );
    if (saved case Err<void>(:final Failure failure)) {
      await _projects.delete(project.id);
      await _removeFiles(storedPages);
      return Err<Project>(failure);
    }
    return Success<Project>(project);
  }

  Future<void> _removeFiles(List<ImagePatternPage> pages) async {
    for (final ImagePatternPage page in pages) {
      await _files.delete(page.path);
    }
  }
}
