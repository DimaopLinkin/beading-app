import 'dart:async';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/image_pattern/image_processor.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/steps/repeat.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/step_pattern_paths.dart';
import 'package:beading/domain/steps/step_pattern_repository.dart';
import 'package:beading/domain/steps/use_cases/save_step_pattern.dart';
import 'package:beading/presentation/steps/steps_editor_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Правка пошаговой инструкции: рабочая копия в памяти, автосохранение с задержкой, фото из камеры и галереи.
///
/// Перед закрытием экрана несохранённая правка дописывается. Удалённый шаг можно вернуть: пока висит баннер,
/// запись откладывается, чтобы файлы его картинок не успели удалиться.
class StepsEditorCubit extends Cubit<StepsEditorState> {
  StepsEditorCubit({
    required String projectId,
    required ProjectRepository projects,
    required StepPatternRepository patterns,
    required SaveStepPattern savePattern,
    required ImageProcessor processor,
    required FileStore files,
    required IdGenerator ids,
    this.debounce = const Duration(milliseconds: 700),
    this.undoDuration = const Duration(seconds: 5),
  }) : _projectId = projectId,
       _projects = projects,
       _patterns = patterns,
       _save = savePattern,
       _processor = processor,
       _files = files,
       _ids = ids,
       super(const StepsEditorState());

  final Duration debounce;
  final Duration undoDuration;

  final String _projectId;
  final ProjectRepository _projects;
  final StepPatternRepository _patterns;
  final SaveStepPattern _save;
  final ImageProcessor _processor;
  final FileStore _files;
  final IdGenerator _ids;

  /// Картинки удалённого шага, пока его можно вернуть: файлы не трогаем.
  final Set<String> _keepImages = <String>{};

  Timer? _saveTimer;
  Timer? _undoTimer;
  Future<void> _writes = Future<void>.value();

  Future<void> load() async {
    final Result<Project> project = await _projects.get(_projectId);
    final Result<StepPattern> pattern = await _patterns.getByProject(_projectId);
    if (isClosed) {
      return;
    }
    if (project.isFailure || pattern.isFailure) {
      emit(state.copyWith(status: StepsEditorStatus.failed));
      return;
    }
    emit(
      state.copyWith(
        status: StepsEditorStatus.ready,
        projectName: project.valueOrNull!.name,
        pattern: pattern.valueOrNull,
      ),
    );
  }

  // ----- секции -----

  void addSection() => _edit(
    (p) => p.copyWith(
      sections: <StepSection>[
        ...p.sections,
        StepSection(
          id: _ids.next(),
          steps: <InstructionStep>[InstructionStep(id: _ids.next())],
        ),
      ],
    ),
  );

  void renameSection(String sectionId, String title) => _section(sectionId, (s) => s.copyWith(title: title));

  void setSectionRepeat(String sectionId, Repeat repeat) => _section(sectionId, (s) => s.copyWith(repeat: repeat));

  /// Сдвигает секцию на [delta] позиций (−1 выше, +1 ниже).
  void moveSection(String sectionId, int delta) => _edit((p) {
    final List<StepSection> list = <StepSection>[...p.sections];
    final int from = list.indexWhere((s) => s.id == sectionId);
    final int to = from + delta;
    if (from < 0 || to < 0 || to >= list.length) {
      return p;
    }
    list.insert(to, list.removeAt(from));
    return p.copyWith(sections: list);
  });

  void duplicateSection(String sectionId) => _edit((p) {
    final int at = p.sections.indexWhere((s) => s.id == sectionId);
    if (at < 0) {
      return p;
    }
    final StepSection source = p.sections[at];
    final StepSection copy = StepSection(
      id: _ids.next(),
      title: source.title,
      repeat: source.repeat,
      steps: <InstructionStep>[
        for (final InstructionStep s in source.steps)
          InstructionStep(id: _ids.next(), text: s.text, imageIds: s.imageIds, beads: s.beads, repeat: s.repeat),
      ],
    );
    return p.copyWith(sections: <StepSection>[...p.sections]..insert(at + 1, copy));
  });

  void deleteSection(String sectionId) => _edit(
    (p) => p.copyWith(
      sections: <StepSection>[
        for (final StepSection s in p.sections)
          if (s.id != sectionId) s,
      ],
    ),
  );

  // ----- шаги -----

  /// Новый пустой шаг в конце секции; возвращает его id.
  String? addStep(String sectionId) {
    final String id = _ids.next();
    _section(
      sectionId,
      (s) => s.copyWith(
        steps: <InstructionStep>[
          ...s.steps,
          InstructionStep(id: id),
        ],
      ),
    );
    return id;
  }

  void setStepText(String stepId, String text) => _step(stepId, (s) => s.copyWith(text: text));

  void setStepRepeat(String stepId, Repeat repeat) => _step(stepId, (s) => s.copyWith(repeat: repeat));

  void reorderSteps(String sectionId, int oldIndex, int newIndex) => _section(sectionId, (s) {
    final List<InstructionStep> list = <InstructionStep>[...s.steps];
    if (oldIndex < 0 || oldIndex >= list.length) {
      return s;
    }
    final int target = (newIndex > oldIndex ? newIndex - 1 : newIndex).clamp(0, list.length - 1);
    list.insert(target, list.removeAt(oldIndex));
    return s.copyWith(steps: list);
  });

  void duplicateStep(String stepId) => _edit(
    (p) => p.copyWith(
      sections: <StepSection>[
        for (final StepSection s in p.sections)
          s.copyWith(
            steps: <InstructionStep>[
              for (final InstructionStep st in s.steps) ...<InstructionStep>[
                st,
                if (st.id == stepId)
                  InstructionStep(
                    id: _ids.next(),
                    text: st.text,
                    imageIds: st.imageIds,
                    beads: st.beads,
                    repeat: st.repeat,
                  ),
              ],
            ],
          ),
      ],
    ),
  );

  /// Удаляет шаг без вопроса; баннер «Шаг удалён · Отменить» держится [undoDuration].
  void deleteStep(String stepId) {
    final StepPattern? p = state.pattern;
    if (p == null) {
      return;
    }
    for (final StepSection s in p.sections) {
      final int at = s.steps.indexWhere((st) => st.id == stepId);
      if (at >= 0) {
        final DeletedStep deleted = DeletedStep(sectionId: s.id, index: at, step: s.steps[at]);
        _keepImages.addAll(deleted.step.imageIds);
        _edit(
          (pattern) => pattern.copyWith(
            sections: <StepSection>[
              for (final StepSection sec in pattern.sections)
                sec.id == s.id ? sec.copyWith(steps: <InstructionStep>[...sec.steps]..removeAt(at)) : sec,
            ],
          ),
          deleted: deleted,
        );
        _undoTimer?.cancel();
        _undoTimer = Timer(undoDuration, dismissUndo);
        return;
      }
    }
  }

  void undoDelete() {
    final DeletedStep? d = state.deleted;
    if (d == null) {
      return;
    }
    _undoTimer?.cancel();
    _edit(
      (p) => p.copyWith(
        sections: <StepSection>[
          for (final StepSection s in p.sections)
            s.id == d.sectionId
                ? s.copyWith(
                    steps: <InstructionStep>[...s.steps]..insert(d.index.clamp(0, s.steps.length), d.step),
                  )
                : s,
        ],
      ),
      clearDeleted: true,
    );
  }

  void dismissUndo() {
    _undoTimer?.cancel();
    _keepImages.clear();
    if (state.deleted != null) {
      emit(state.copyWith(clearDeleted: true, save: StepsSaveStatus.pending));
      _schedule(); // запись уберёт файлы картинок удалённого шага
    }
  }

  // ----- бусины -----

  /// Добавляет бусины цвета [color] в шаг; цвет попадает в палитру работы, если его там ещё нет.
  void addBead(String stepId, PatternColor color, {int count = 1}) => _edit((p) {
    int index = p.palette.indexOf(color);
    final List<PatternColor> palette = index >= 0 ? p.palette : <PatternColor>[...p.palette, color];
    if (index < 0) {
      index = palette.length - 1;
    }
    return _withStep(p.copyWith(palette: palette), stepId, (s) {
      final List<StepBead> beads = <StepBead>[...s.beads];
      final int existing = beads.indexWhere((b) => b.colorIndex == index);
      if (existing >= 0) {
        beads[existing] = StepBead(colorIndex: index, count: beads[existing].count + count);
      } else {
        beads.add(StepBead(colorIndex: index, count: count));
      }
      return s.copyWith(beads: beads);
    });
  });

  void setBeadCount(String stepId, int colorIndex, int count) => _step(
    stepId,
    (s) => s.copyWith(
      beads: <StepBead>[
        for (final StepBead b in s.beads)
          if (b.colorIndex != colorIndex) b else if (count >= 1) StepBead(colorIndex: colorIndex, count: count),
      ],
    ),
  );

  // ----- фото -----

  /// Добавляет фото в конец картинок шага: PNG пишется в хранилище, запись документа — автосохранением.
  Future<void> addPhotos(String stepId, List<Uint8List> photos) async {
    final StepPattern? start = state.pattern;
    if (start == null || photos.isEmpty) {
      return;
    }
    emit(state.copyWith(photoFailed: false));
    for (final Uint8List bytes in photos) {
      final Result<ProcessedImage> processed = await _processor.process(bytes);
      if (isClosed) {
        return;
      }
      final String id = _ids.next();
      final String path = stepImagePath(patternId: start.id, imageId: id);
      final Result<void> written = processed.isFailure
          ? Err<void>(processed.failureOrNull!)
          : await _files.write(path, processed.valueOrNull!.png);
      if (written.isFailure) {
        if (!isClosed) {
          emit(state.copyWith(photoFailed: true));
        }
        continue;
      }
      if (isClosed || state.stepById(stepId) == null) {
        await _files.delete(path); // экран закрыт или шаг удалён, пока шла обработка: файл никому не нужен
        return;
      }
      final ProcessedImage image = processed.valueOrNull!;
      _edit(
        (p) => _withStep(
          p.copyWith(
            images: <StepImage>[
              ...p.images,
              StepImage(id: id, path: path, width: image.width, height: image.height),
            ],
          ),
          stepId,
          (s) => s.copyWith(imageIds: <String>[...s.imageIds, id]),
        ),
      );
    }
  }

  /// Выбор фото не открылся (нет доступа к камере или Фото).
  void photoPickFailed() => emit(state.copyWith(photoFailed: true));

  void removeImage(String stepId, String imageId) =>
      _step(stepId, (s) => s.copyWith(imageIds: <String>[...s.imageIds]..remove(imageId)));

  void reorderImages(String stepId, int oldIndex, int newIndex) => _step(stepId, (s) {
    final List<String> list = <String>[...s.imageIds];
    if (oldIndex < 0 || oldIndex >= list.length) {
      return s;
    }
    final int target = (newIndex > oldIndex ? newIndex - 1 : newIndex).clamp(0, list.length - 1);
    list.insert(target, list.removeAt(oldIndex));
    return s.copyWith(imageIds: list);
  });

  // ----- внутреннее -----

  StepPattern _withStep(StepPattern p, String stepId, InstructionStep Function(InstructionStep) change) => p.copyWith(
    sections: <StepSection>[
      for (final StepSection s in p.sections)
        s.copyWith(
          steps: <InstructionStep>[for (final InstructionStep st in s.steps) st.id == stepId ? change(st) : st],
        ),
    ],
  );

  void _step(String stepId, InstructionStep Function(InstructionStep) change) =>
      _edit((p) => _withStep(p, stepId, change));

  void _section(String sectionId, StepSection Function(StepSection) change) => _edit(
    (p) =>
        p.copyWith(sections: <StepSection>[for (final StepSection s in p.sections) s.id == sectionId ? change(s) : s]),
  );

  void _edit(StepPattern Function(StepPattern) change, {DeletedStep? deleted, bool clearDeleted = false}) {
    final StepPattern? p = state.pattern;
    if (p == null || !state.isReady) {
      return;
    }
    final StepPattern next = change(p);
    if (next == p && deleted == null && !clearDeleted) {
      return;
    }
    emit(state.copyWith(pattern: next, save: StepsSaveStatus.pending, deleted: deleted, clearDeleted: clearDeleted));
    _schedule();
  }

  void _schedule() {
    if (isClosed) {
      return;
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(debounce, _flush);
  }

  void _flush() {
    final StepPattern? p = state.pattern;
    if (p == null) {
      return;
    }
    _writes = _writes.then((_) async {
      Result<void> saved;
      try {
        saved = await _save(p, keepImageIds: <String>{..._keepImages});
      } on Object catch (error) {
        saved = Err<void>(StorageFailure('$error'));
      }
      if (!isClosed && state.pattern == p) {
        emit(state.copyWith(save: saved.isSuccess ? StepsSaveStatus.saved : StepsSaveStatus.failed));
      } else if (!isClosed && saved.isFailure) {
        emit(state.copyWith(save: StepsSaveStatus.failed));
      }
    });
  }

  /// Дописывает несохранённую правку; зовётся при закрытии экрана.
  Future<void> flush() async {
    _saveTimer?.cancel();
    _undoTimer?.cancel();
    if (state.save != StepsSaveStatus.saved) {
      _flush();
    }
    await _writes;
  }

  @override
  Future<void> close() async {
    await flush();
    await super.close();
  }
}
