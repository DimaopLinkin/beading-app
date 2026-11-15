import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_content_cleaner.dart';
import 'package:beading/domain/projects/project_content_cloner.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/step_pattern_paths.dart';
import 'package:beading/domain/steps/step_pattern_repository.dart';

/// Копирует инструкцию в новый проект при дублировании: документ и картинки (файлы копируются, а не делятся).
/// Прогресс не копируется: копию начинают с начала.
class StepPatternContentCloner implements ProjectContentCloner {
  const StepPatternContentCloner({
    required StepPatternRepository patterns,
    required ProjectRepository projects,
    required FileStore files,
    required IdGenerator ids,
  }) : _patterns = patterns,
       _projects = projects,
       _files = files,
       _ids = ids;

  final StepPatternRepository _patterns;
  final ProjectRepository _projects;
  final FileStore _files;
  final IdGenerator _ids;

  @override
  bool supports(ContentKind kind) => kind == ContentKind.steps;

  @override
  Future<Result<void>> clone({required Project source, required String targetId}) async {
    final Result<StepPattern> found = await _patterns.getByProject(source.id);
    if (found case Err<StepPattern>(:final Failure failure)) {
      return failure is NotFoundFailure ? const Success<void>(null) : Err<void>(failure);
    }
    final StepPattern original = found.valueOrNull!;
    final String patternId = _ids.next();
    final Map<String, String> imageIds = <String, String>{};
    final List<StepImage> copied = <StepImage>[];
    for (final StepImage image in original.images) {
      final String id = _ids.next();
      final String path = stepImagePath(patternId: patternId, imageId: id);
      final Result<void> done = await _files.copy(from: image.path, to: path);
      if (done case Err<void>(:final Failure failure)) {
        await _removeFiles(copied);
        return Err<void>(failure);
      }
      imageIds[image.id] = id;
      copied.add(StepImage(id: id, path: path, width: image.width, height: image.height));
    }
    final StepPattern copy = StepPattern(
      id: patternId,
      projectId: targetId,
      palette: original.palette,
      templateId: original.templateId,
      images: copied,
      sections: <StepSection>[
        for (final StepSection s in original.sections)
          s.copyWith(
            steps: <InstructionStep>[
              for (final InstructionStep st in s.steps)
                st.copyWith(
                  imageIds: <String>[
                    for (final String i in st.imageIds)
                      if (imageIds[i] != null) imageIds[i]!,
                  ],
                ),
            ],
          ),
      ],
    );
    final Result<void> saved = await _patterns.save(copy);
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

  Future<void> _removeFiles(List<StepImage> images) async {
    for (final StepImage image in images) {
      await _files.delete(image.path);
    }
  }
}

/// Удаляет файлы картинок и инструкцию удалённого проекта.
class StepPatternContentCleaner implements ProjectContentCleaner {
  const StepPatternContentCleaner({required StepPatternRepository patterns, required FileStore files})
    : _patterns = patterns,
      _files = files;

  final StepPatternRepository _patterns;
  final FileStore _files;

  @override
  bool supports(ContentKind kind) => kind == ContentKind.steps;

  @override
  Future<Result<void>> remove(Project project) async {
    final Result<StepPattern> found = await _patterns.getByProject(project.id);
    if (found case Err<StepPattern>(:final Failure failure)) {
      return failure is NotFoundFailure ? const Success<void>(null) : Err<void>(failure);
    }
    Failure? firstFailure;
    for (final StepImage image in found.valueOrNull!.images) {
      final Result<void> deleted = await _files.delete(image.path);
      firstFailure ??= deleted.failureOrNull;
    }
    final Result<void> dropped = await _patterns.deleteByProject(project.id);
    firstFailure ??= dropped.failureOrNull;
    return firstFailure == null ? const Success<void>(null) : Err<void>(firstFailure);
  }
}
