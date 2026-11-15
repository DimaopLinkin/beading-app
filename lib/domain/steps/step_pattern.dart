import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/steps/repeat.dart';
import 'package:equatable/equatable.dart';

/// Бусины шага: цвет палитры и сколько штук («3 × A»).
final class StepBead extends Equatable {
  const StepBead({required this.colorIndex, required this.count}) : assert(count >= 1, 'бусин меньше 1');

  /// Индекс в [StepPattern.palette].
  final int colorIndex;
  final int count;

  @override
  List<Object?> get props => <Object?>[colorIndex, count];
}

/// Картинка шага: файл внутри хранилища приложения.
final class StepImage extends Equatable {
  const StepImage({required this.id, required this.path, required this.width, required this.height});

  final String id;

  /// Путь к PNG относительно хранилища приложения.
  final String path;
  final int width;
  final int height;

  @override
  List<Object?> get props => <Object?>[id, path, width, height];
}

/// Один шаг инструкции. `id` стабилен: прогресс ссылается на него, а не на номер.
final class InstructionStep extends Equatable {
  const InstructionStep({
    required this.id,
    this.text = '',
    this.imageIds = const <String>[],
    this.beads = const <StepBead>[],
    this.repeat = Repeat.once,
  });

  final String id;
  final String text;

  /// Картинки по порядку; сами файлы — в [StepPattern.images].
  final List<String> imageIds;
  final List<StepBead> beads;
  final Repeat repeat;

  InstructionStep copyWith({String? text, List<String>? imageIds, List<StepBead>? beads, Repeat? repeat}) =>
      InstructionStep(
        id: id,
        text: text ?? this.text,
        imageIds: imageIds ?? this.imageIds,
        beads: beads ?? this.beads,
        repeat: repeat ?? this.repeat,
      );

  @override
  List<Object?> get props => <Object?>[id, text, imageIds, beads, repeat];
}

/// Секция: шаги, которые повторяются вместе. Одна безымянная секция — плоский список шагов.
final class StepSection extends Equatable {
  const StepSection({required this.id, this.title = '', this.repeat = Repeat.once, required this.steps});

  final String id;
  final String title;
  final Repeat repeat;
  final List<InstructionStep> steps;

  StepSection copyWith({String? title, Repeat? repeat, List<InstructionStep>? steps}) => StepSection(
    id: id,
    title: title ?? this.title,
    repeat: repeat ?? this.repeat,
    steps: steps ?? this.steps,
  );

  @override
  List<Object?> get props => <Object?>[id, title, repeat, steps];
}

/// Пошаговая инструкция проекта с `contentKind = steps` (ADR-0008).
final class StepPattern extends Equatable {
  const StepPattern({
    required this.id,
    required this.projectId,
    this.palette = const <PatternColor>[],
    required this.sections,
    this.images = const <StepImage>[],
    this.templateId,
  });

  final String id;
  final String projectId;

  /// Снимок цветов: правка каталога не меняет инструкцию.
  final List<PatternColor> palette;
  final List<StepSection> sections;

  /// Файлы картинок; в документ (кодек) не входят, лежат в таблице `step_images`.
  final List<StepImage> images;

  /// Из какого встроенного шаблона создана инструкция; `null` у пустой и «из фото».
  final String? templateId;

  /// Все шаги по порядку, без учёта секций.
  Iterable<InstructionStep> get allSteps sync* {
    for (final StepSection section in sections) {
      yield* section.steps;
    }
  }

  /// Идентификаторы картинок, на которые ссылаются шаги.
  Set<String> get referencedImageIds => <String>{for (final InstructionStep s in allSteps) ...s.imageIds};

  StepPattern copyWith({
    List<PatternColor>? palette,
    List<StepSection>? sections,
    List<StepImage>? images,
  }) => StepPattern(
    id: id,
    projectId: projectId,
    palette: palette ?? this.palette,
    sections: sections ?? this.sections,
    images: images ?? this.images,
    templateId: templateId,
  );

  @override
  List<Object?> get props => <Object?>[id, projectId, palette, sections, images, templateId];
}
