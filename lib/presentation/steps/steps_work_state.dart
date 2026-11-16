import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/steps_progress.dart';
import 'package:equatable/equatable.dart';

enum StepsWorkStatus { loading, ready, failed }

/// Экран «инструкция в работе»: где мастерица сейчас и что показать на этом шаге.
///
/// Номер шага считает шаги, как их написала мастерица, а не развёрнутые повторы (ADR-0008).
class StepsWorkState extends Equatable {
  const StepsWorkState({
    this.status = StepsWorkStatus.loading,
    this.projectName = '',
    this.projectDone = false,
    this.pattern,
    this.progress,
    this.saveFailed = false,
  });

  final StepsWorkStatus status;
  final String projectName;
  final bool projectDone;
  final StepPattern? pattern;
  final StepsProgress? progress;

  /// Последняя запись не удалась; пропадает после следующей удачной.
  final bool saveFailed;

  bool get isReady => status == StepsWorkStatus.ready && pattern != null && progress != null;

  /// Пустая инструкция: шагов нет совсем.
  bool get isEmpty => pattern == null || pattern!.allSteps.isEmpty;

  int get totalSteps => pattern?.allSteps.length ?? 0;

  int get _sectionIndex => pattern!.sections.indexWhere((s) => s.id == progress!.sectionId);

  StepSection? get section => isReady && _sectionIndex >= 0 ? pattern!.sections[_sectionIndex] : null;

  InstructionStep? get step {
    final StepSection? s = section;
    if (s == null) {
      return null;
    }
    for (final InstructionStep step in s.steps) {
      if (step.id == progress!.stepId) {
        return step;
      }
    }
    return null;
  }

  /// Номер секции среди непустых, с единицы, и число таких секций.
  (int, int) get sectionNumber {
    final List<StepSection> filled = pattern!.sections.where((s) => s.steps.isNotEmpty).toList();
    return (filled.indexWhere((s) => s.id == progress!.sectionId) + 1, filled.length);
  }

  /// Номер текущего шага среди всех шагов, с единицы.
  int get stepNumber => pattern!.allSteps.toList().indexWhere((s) => s.id == progress!.stepId) + 1;

  /// Все шаги пройдены.
  bool get finished => !isEmpty && (progress?.finished ?? false);

  /// Шаг последний: «дальше» закончит работу.
  bool get isLastStep => isReady && !finished && progress!.next(pattern!).finished;

  /// У шага или секции повтор «до нужной длины»: показываем «Достаточно».
  bool get canSkipRepeat =>
      isReady && !finished && ((step?.repeat.isUntilDone ?? false) || (section?.repeat.isUntilDone ?? false));

  /// Откатываться некуда: самое начало.
  bool get isAtStart => isReady && !finished && progress == progress!.previous(pattern!);

  double get fraction => isReady ? progress!.fraction(pattern!) : 0;

  StepsWorkState copyWith({
    StepsWorkStatus? status,
    String? projectName,
    bool? projectDone,
    StepPattern? pattern,
    StepsProgress? progress,
    bool? saveFailed,
  }) => StepsWorkState(
    status: status ?? this.status,
    projectName: projectName ?? this.projectName,
    projectDone: projectDone ?? this.projectDone,
    pattern: pattern ?? this.pattern,
    progress: progress ?? this.progress,
    saveFailed: saveFailed ?? this.saveFailed,
  );

  @override
  List<Object?> get props => <Object?>[status, projectName, projectDone, pattern, progress, saveFailed];
}
