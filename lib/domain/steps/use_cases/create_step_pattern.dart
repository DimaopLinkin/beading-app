import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/image_pattern/image_processor.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/step_pattern_paths.dart';
import 'package:beading/domain/steps/step_pattern_repository.dart';
import 'package:beading/domain/steps/step_template.dart';

/// Создаёт проект с `contentKind = steps` тремя способами: пустой, из встроенного шаблона и из фото.
/// При любой ошибке не оставляет ни проекта, ни файлов.
class CreateStepPattern {
  const CreateStepPattern({
    required CreateProject createProject,
    required ProjectRepository projects,
    required StepPatternRepository patterns,
    required StepTemplateSource templates,
    required ImageProcessor processor,
    required FileStore files,
    required IdGenerator ids,
  }) : _createProject = createProject,
       _projects = projects,
       _patterns = patterns,
       _templates = templates,
       _processor = processor,
       _files = files,
       _ids = ids;

  final CreateProject _createProject;
  final ProjectRepository _projects;
  final StepPatternRepository _patterns;
  final StepTemplateSource _templates;
  final ImageProcessor _processor;
  final FileStore _files;
  final IdGenerator _ids;

  /// Одна секция с одним пустым шагом.
  Future<Result<Project>> empty({required String name, Technique technique = Technique.offLoom}) => _create(
    name: name,
    technique: technique,
    build: (patternId) async {
      return Success<_Built>(
        _Built(
          sections: <StepSection>[
            StepSection(
              id: _ids.next(),
              steps: <InstructionStep>[InstructionStep(id: _ids.next())],
            ),
          ],
        ),
      );
    },
  );

  /// Копия шаблона [templateId]: картинки переезжают в хранилище проекта, id шагов и секций выдаются заново.
  Future<Result<Project>> fromTemplate({
    required String name,
    required String templateId,
    Technique technique = Technique.offLoom,
  }) async {
    if (technique.craft != Craft.beading) {
      return const Err<Project>(ValidationFailure('Инструкции только для бисера'));
    }
    final Result<StepTemplate> found = await _templates.get(templateId);
    if (found case Err<StepTemplate>(:final Failure failure)) {
      return Err<Project>(failure);
    }
    final StepTemplate template = found.valueOrNull!;
    return _create(
      name: name,
      technique: technique,
      templateId: templateId,
      build: (patternId) async {
        final Map<String, String> imageIds = <String, String>{};
        final List<StepImage> images = <StepImage>[];
        for (final StepTemplateImage source in template.images) {
          final String id = _ids.next();
          final String path = stepImagePath(patternId: patternId, imageId: id);
          final Result<void> written = await _files.write(path, source.png);
          if (written case Err<void>(:final Failure failure)) {
            await _removeFiles(images);
            return Err<_Built>(failure);
          }
          imageIds[source.id] = id;
          images.add(StepImage(id: id, path: path, width: source.width, height: source.height));
        }
        return Success<_Built>(
          _Built(
            palette: template.palette,
            images: images,
            sections: <StepSection>[
              for (final StepSection s in template.sections)
                StepSection(
                  id: _ids.next(),
                  title: s.title,
                  repeat: s.repeat,
                  steps: <InstructionStep>[
                    for (final InstructionStep st in s.steps)
                      InstructionStep(
                        id: _ids.next(),
                        text: st.text,
                        beads: st.beads,
                        repeat: st.repeat,
                        // Ссылка на картинку, которой нет в шаблоне, — не ошибка: просто без неё.
                        imageIds: <String>[
                          for (final String i in st.imageIds)
                            if (imageIds[i] != null) imageIds[i]!,
                        ],
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  /// По одному шагу на фото, текст пустой. Не генератор и не распознавание текста.
  Future<Result<Project>> fromPhotos({
    required String name,
    required List<Uint8List> photos,
    Technique technique = Technique.offLoom,
  }) async {
    if (technique.craft != Craft.beading) {
      return const Err<Project>(ValidationFailure('Инструкции только для бисера'));
    }
    if (photos.isEmpty) {
      return const Err<Project>(ValidationFailure('Нужна хотя бы одна фотография'));
    }
    final List<ProcessedImage> processed = <ProcessedImage>[];
    for (final Uint8List bytes in photos) {
      final Result<ProcessedImage> result = await _processor.process(bytes);
      if (result case Err<ProcessedImage>(:final Failure failure)) {
        return Err<Project>(failure);
      }
      processed.add(result.valueOrNull!);
    }
    return _create(
      name: name,
      technique: technique,
      build: (patternId) async {
        final List<StepImage> images = <StepImage>[];
        for (final ProcessedImage image in processed) {
          final String id = _ids.next();
          final String path = stepImagePath(patternId: patternId, imageId: id);
          final Result<void> written = await _files.write(path, image.png);
          if (written case Err<void>(:final Failure failure)) {
            await _removeFiles(images);
            return Err<_Built>(failure);
          }
          images.add(StepImage(id: id, path: path, width: image.width, height: image.height));
        }
        return Success<_Built>(
          _Built(
            images: images,
            sections: <StepSection>[
              StepSection(
                id: _ids.next(),
                steps: <InstructionStep>[
                  for (final StepImage i in images) InstructionStep(id: _ids.next(), imageIds: <String>[i.id]),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Result<Project>> _create({
    required String name,
    required Technique technique,
    required Future<Result<_Built>> Function(String patternId) build,
    String? templateId,
  }) async {
    if (technique.craft != Craft.beading) {
      return const Err<Project>(ValidationFailure('Инструкции только для бисера'));
    }
    final String patternId = _ids.next();
    final Result<_Built> built = await build(patternId);
    if (built case Err<_Built>(:final Failure failure)) {
      return Err<Project>(failure);
    }
    final _Built content = built.valueOrNull!;
    final Result<Project> created = await _createProject(
      name: name,
      technique: technique,
      contentKind: ContentKind.steps,
      coverPath: content.images.isEmpty ? null : content.images.first.path,
    );
    if (created case Err<Project>()) {
      await _removeFiles(content.images);
      return created;
    }
    final Project project = created.valueOrNull!;
    final Result<void> saved = await _patterns.save(
      StepPattern(
        id: patternId,
        projectId: project.id,
        palette: content.palette,
        sections: content.sections,
        images: content.images,
        templateId: templateId,
      ),
    );
    if (saved case Err<void>(:final Failure failure)) {
      await _projects.delete(project.id);
      await _removeFiles(content.images);
      return Err<Project>(failure);
    }
    return Success<Project>(project);
  }

  Future<void> _removeFiles(List<StepImage> images) async {
    for (final StepImage image in images) {
      await _files.delete(image.path);
    }
  }
}

class _Built {
  const _Built({this.palette = const [], this.images = const [], required this.sections});

  final List<PatternColor> palette;
  final List<StepImage> images;
  final List<StepSection> sections;
}
