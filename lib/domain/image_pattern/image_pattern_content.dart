import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';
import 'package:beading/domain/image_pattern/image_pattern_paths.dart';
import 'package:beading/domain/image_pattern/image_pattern_repository.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_content_cleaner.dart';
import 'package:beading/domain/projects/project_content_cloner.dart';
import 'package:beading/domain/projects/project_repository.dart';

/// Копирует страницы схемы-картинки в новый проект при дублировании (файлы копируются, а не делятся).
class ImagePatternContentCloner implements ProjectContentCloner {
  const ImagePatternContentCloner({
    required ImagePatternRepository patterns,
    required ProjectRepository projects,
    required FileStore files,
    required IdGenerator ids,
  }) : _patterns = patterns,
       _projects = projects,
       _files = files,
       _ids = ids;

  final ImagePatternRepository _patterns;
  final ProjectRepository _projects;
  final FileStore _files;
  final IdGenerator _ids;

  @override
  bool supports(ContentKind kind) => kind == ContentKind.image;

  @override
  Future<Result<void>> clone({required Project source, required String targetId}) async {
    final Result<ImagePattern> found = await _patterns.getByProject(source.id);
    if (found case Err<ImagePattern>(:final Failure failure)) {
      // У проекта-картинки может ещё не быть схемы (пустой проект): копировать нечего.
      return failure is NotFoundFailure ? const Success<void>(null) : Err<void>(failure);
    }
    final ImagePattern original = found.valueOrNull!;
    final String patternId = _ids.next();
    final List<ImagePatternPage> copied = <ImagePatternPage>[];
    for (final ImagePatternPage page in original.pages) {
      final String pageId = _ids.next();
      final String path = imagePatternPagePath(patternId: patternId, pageId: pageId);
      final Result<void> done = await _files.copy(from: page.path, to: path);
      if (done case Err<void>(:final Failure failure)) {
        await _removeFiles(copied);
        return Err<void>(failure);
      }
      copied.add(ImagePatternPage(id: pageId, path: path, width: page.width, height: page.height));
    }
    final Result<void> saved = await _patterns.save(
      ImagePattern(id: patternId, projectId: targetId, pages: copied),
    );
    if (saved case Err<void>()) {
      await _removeFiles(copied);
      return saved;
    }
    if (copied.isNotEmpty) {
      final Result<Project> target = await _projects.get(targetId);
      if (target case Success<Project>(:final Project value)) {
        final Result<void> covered = await _projects.save(value.withCoverPath(copied.first.path));
        if (covered case Err<void>()) {
          await _patterns.deleteByProject(targetId);
          await _removeFiles(copied);
          return covered;
        }
      }
    }
    return const Success<void>(null);
  }

  Future<void> _removeFiles(List<ImagePatternPage> pages) async {
    for (final ImagePatternPage page in pages) {
      await _files.delete(page.path);
    }
  }
}

/// Удаляет файлы страниц и схему удалённого проекта.
class ImagePatternContentCleaner implements ProjectContentCleaner {
  const ImagePatternContentCleaner({required ImagePatternRepository patterns, required FileStore files})
    : _patterns = patterns,
      _files = files;

  final ImagePatternRepository _patterns;
  final FileStore _files;

  @override
  bool supports(ContentKind kind) => kind == ContentKind.image;

  @override
  Future<Result<void>> remove(Project project) async {
    final Result<ImagePattern> found = await _patterns.getByProject(project.id);
    if (found case Err<ImagePattern>(:final Failure failure)) {
      return failure is NotFoundFailure ? const Success<void>(null) : Err<void>(failure);
    }
    Failure? firstFailure;
    for (final ImagePatternPage page in found.valueOrNull!.pages) {
      final Result<void> deleted = await _files.delete(page.path);
      firstFailure ??= deleted.failureOrNull;
    }
    final Result<void> dropped = await _patterns.deleteByProject(project.id);
    firstFailure ??= dropped.failureOrNull;
    return firstFailure == null ? const Success<void>(null) : Err<void>(firstFailure);
  }
}
