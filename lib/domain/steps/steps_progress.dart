import 'package:beading/domain/steps/step_pattern.dart';
import 'package:equatable/equatable.dart';

/// Где остановилась мастерица: курсор по развёрнутой последовательности шагов (ADR-0008).
///
/// Сделано всё, что раньше курсора. Проходы считаются с 1. У «до нужной длины» проход растёт, пока
/// не нажали «Достаточно» ([skipRepeat]).
final class StepsProgress extends Equatable {
  const StepsProgress({
    required this.sectionId,
    required this.sectionPass,
    required this.stepId,
    required this.stepPass,
    this.finished = false,
  });

  /// Начало инструкции. Если в ней нет ни одного шага, она считается пройденной.
  factory StepsProgress.start(StepPattern pattern) {
    for (final StepSection section in pattern.sections) {
      if (section.steps.isNotEmpty) {
        return StepsProgress(
          sectionId: section.id,
          sectionPass: 1,
          stepId: section.steps.first.id,
          stepPass: 1,
        );
      }
    }
    return const StepsProgress(sectionId: '', sectionPass: 1, stepId: '', stepPass: 1, finished: true);
  }

  final String sectionId;
  final int sectionPass;
  final String stepId;
  final int stepPass;

  /// Все шаги пройдены.
  final bool finished;

  /// Следующий шаг: ещё проход шага, потом следующий шаг, потом ещё проход секции, потом следующая секция.
  /// У шага или секции «до нужной длины» проход растёт без предела. На пройденной инструкции ничего не меняет.
  StepsProgress next(StepPattern pattern) {
    final _Pos? pos = _Pos.locate(pattern, this);
    if (finished || pos == null) {
      return finished ? this : StepsProgress.start(pattern);
    }
    final InstructionStep step = pos.step;
    if (step.repeat.isUntilDone || stepPass < step.repeat.passes) {
      return _copy(stepPass: stepPass + 1);
    }
    return _afterStep(pattern, pos);
  }

  /// «Достаточно»: выйти из повторов «до нужной длины» самого глубокого уровня и идти дальше.
  /// Если шаг повторяется «N раз», то это просто следующий шаг.
  StepsProgress skipRepeat(StepPattern pattern) {
    final _Pos? pos = _Pos.locate(pattern, this);
    if (finished || pos == null) {
      return this;
    }
    if (pos.step.repeat.isUntilDone) {
      return _afterStep(pattern, pos);
    }
    if (pos.section.repeat.isUntilDone) {
      return _nextSection(pattern, pos.sectionIndex);
    }
    return next(pattern);
  }

  /// Шаг назад. С пройденной инструкции возвращает на последний шаг. В самом начале остаётся на месте.
  StepsProgress previous(StepPattern pattern) {
    if (finished) {
      return _last(pattern) ?? StepsProgress.start(pattern);
    }
    final _Pos? pos = _Pos.locate(pattern, this);
    if (pos == null) {
      return StepsProgress.start(pattern);
    }
    if (stepPass > 1) {
      return _copy(stepPass: stepPass - 1);
    }
    if (pos.stepIndex > 0) {
      final InstructionStep prev = pos.section.steps[pos.stepIndex - 1];
      return _copy(stepId: prev.id, stepPass: prev.repeat.passes);
    }
    if (sectionPass > 1) {
      final InstructionStep last = pos.section.steps.last;
      return _copy(sectionPass: sectionPass - 1, stepId: last.id, stepPass: last.repeat.passes);
    }
    for (int i = pos.sectionIndex - 1; i >= 0; i--) {
      final StepSection section = pattern.sections[i];
      if (section.steps.isNotEmpty) {
        final InstructionStep last = section.steps.last;
        return StepsProgress(
          sectionId: section.id,
          sectionPass: section.repeat.passes,
          stepId: last.id,
          stepPass: last.repeat.passes,
        );
      }
    }
    return this;
  }

  /// Перейти на начало шага [stepId] (касание в списке шагов). Нет такого шага — прогресс не меняется.
  StepsProgress jumpTo(StepPattern pattern, String stepId) {
    for (final StepSection section in pattern.sections) {
      for (final InstructionStep step in section.steps) {
        if (step.id == stepId) {
          return StepsProgress(sectionId: section.id, sectionPass: 1, stepId: step.id, stepPass: 1);
        }
      }
    }
    return this;
  }

  /// Доля пройденного, 0..1. Шаг и секция «до нужной длины» считаются за один проход.
  double fraction(StepPattern pattern) {
    if (!finished && _Pos.locate(pattern, this) == null) {
      return 0; // курсор указывает на несуществующий шаг: честнее не обещать готовности
    }
    int total = 0;
    int done = 0;
    bool reached = finished;
    for (final StepSection section in pattern.sections) {
      final int perPass = section.steps.fold<int>(0, (sum, s) => sum + s.repeat.passes);
      total += section.repeat.passes * perPass;
      if (finished) {
        done = total;
        continue;
      }
      if (reached) {
        continue;
      }
      if (section.id == sectionId) {
        final int pass = (sectionPass - 1).clamp(0, section.repeat.passes - 1);
        done += pass * perPass;
        for (final InstructionStep step in section.steps) {
          if (step.id == stepId) {
            done += (stepPass - 1).clamp(0, step.repeat.passes - 1);
            reached = true;
            break;
          }
          done += step.repeat.passes;
        }
        if (!reached) {
          done += perPass; // курсор указывает на шаг, которого нет: считаем секцию пройденной
        }
      } else {
        done += section.repeat.passes * perPass;
      }
    }
    return total == 0 ? 1 : (done / total).clamp(0.0, 1.0);
  }

  /// Курсор после правки инструкции: шаг под курсором удалили — идём на ближайший следующий из прежних.
  /// Не нашли ни одного — на последний шаг, а в пустой инструкции — в начало.
  StepsProgress reconcile({required StepPattern before, required StepPattern after}) {
    if (finished) {
      return this;
    }
    final Set<String> alive = <String>{for (final InstructionStep s in after.allSteps) s.id};
    if (alive.contains(stepId)) {
      final StepsProgress moved = jumpTo(after, stepId);
      // Секция шага могла смениться (шаг перенесли): проходы секции начинаем заново только в этом случае.
      final _Pos pos = _Pos.locate(after, moved)!;
      final int pass = pos.step.repeat.isUntilDone ? stepPass : stepPass.clamp(1, pos.step.repeat.passes);
      if (moved.sectionId != sectionId) {
        return moved._copyPass(pass);
      }
      final int sPass = pos.section.repeat.isUntilDone ? sectionPass : sectionPass.clamp(1, pos.section.repeat.passes);
      return StepsProgress(sectionId: sectionId, sectionPass: sPass, stepId: stepId, stepPass: pass);
    }
    bool seen = false;
    for (final InstructionStep step in before.allSteps) {
      if (step.id == stepId) {
        seen = true;
        continue;
      }
      if (seen && alive.contains(step.id)) {
        return jumpTo(after, step.id);
      }
    }
    return _last(after) ?? StepsProgress.start(after);
  }

  StepsProgress _copyPass(int pass) =>
      StepsProgress(sectionId: sectionId, sectionPass: sectionPass, stepId: stepId, stepPass: pass);

  StepsProgress _afterStep(StepPattern pattern, _Pos pos) {
    if (pos.stepIndex + 1 < pos.section.steps.length) {
      return _copy(stepId: pos.section.steps[pos.stepIndex + 1].id, stepPass: 1);
    }
    if (pos.section.repeat.isUntilDone || sectionPass < pos.section.repeat.passes) {
      return _copy(sectionPass: sectionPass + 1, stepId: pos.section.steps.first.id, stepPass: 1);
    }
    return _nextSection(pattern, pos.sectionIndex);
  }

  StepsProgress _nextSection(StepPattern pattern, int index) {
    for (int i = index + 1; i < pattern.sections.length; i++) {
      final StepSection section = pattern.sections[i];
      if (section.steps.isNotEmpty) {
        return StepsProgress(sectionId: section.id, sectionPass: 1, stepId: section.steps.first.id, stepPass: 1);
      }
    }
    return StepsProgress(
      sectionId: sectionId,
      sectionPass: sectionPass,
      stepId: stepId,
      stepPass: stepPass,
      finished: true,
    );
  }

  static StepsProgress? _last(StepPattern pattern) {
    for (int i = pattern.sections.length - 1; i >= 0; i--) {
      final StepSection section = pattern.sections[i];
      if (section.steps.isNotEmpty) {
        final InstructionStep last = section.steps.last;
        return StepsProgress(
          sectionId: section.id,
          sectionPass: section.repeat.passes,
          stepId: last.id,
          stepPass: last.repeat.passes,
        );
      }
    }
    return null;
  }

  StepsProgress _copy({int? sectionPass, String? stepId, int? stepPass}) => StepsProgress(
    sectionId: sectionId,
    sectionPass: sectionPass ?? this.sectionPass,
    stepId: stepId ?? this.stepId,
    stepPass: stepPass ?? this.stepPass,
  );

  @override
  List<Object?> get props => <Object?>[sectionId, sectionPass, stepId, stepPass, finished];
}

/// Где курсор в структуре инструкции.
final class _Pos {
  const _Pos(this.sectionIndex, this.section, this.stepIndex, this.step);

  final int sectionIndex;
  final StepSection section;
  final int stepIndex;
  final InstructionStep step;

  static _Pos? locate(StepPattern pattern, StepsProgress progress) {
    for (final (int i, StepSection section) in pattern.sections.indexed) {
      if (section.id != progress.sectionId) {
        continue;
      }
      for (final (int j, InstructionStep step) in section.steps.indexed) {
        if (step.id == progress.stepId) {
          return _Pos(i, section, j, step);
        }
      }
    }
    return null;
  }
}
