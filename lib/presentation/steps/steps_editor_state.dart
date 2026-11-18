import 'package:beading/domain/steps/step_pattern.dart';
import 'package:equatable/equatable.dart';

enum StepsEditorStatus { loading, ready, failed }

/// Состояние записи: «Сохранено» показываем только после удачной записи.
enum StepsSaveStatus { saved, pending, failed }

/// Удалённый шаг, который ещё можно вернуть баннером «Шаг удалён · Отменить».
class DeletedStep extends Equatable {
  const DeletedStep({required this.sectionId, required this.index, required this.step});

  final String sectionId;
  final int index;
  final InstructionStep step;

  @override
  List<Object?> get props => <Object?>[sectionId, index, step];
}

/// Редактор инструкции: рабочая копия документа и состояние автосохранения.
class StepsEditorState extends Equatable {
  const StepsEditorState({
    this.status = StepsEditorStatus.loading,
    this.projectName = '',
    this.pattern,
    this.save = StepsSaveStatus.saved,
    this.deleted,
    this.photoFailed = false,
  });

  final StepsEditorStatus status;
  final String projectName;
  final StepPattern? pattern;
  final StepsSaveStatus save;
  final DeletedStep? deleted;

  /// Последнее фото не удалось добавить.
  final bool photoFailed;

  bool get isReady => status == StepsEditorStatus.ready && pattern != null;

  InstructionStep? stepById(String stepId) {
    for (final InstructionStep s in pattern?.allSteps ?? const <InstructionStep>[]) {
      if (s.id == stepId) {
        return s;
      }
    }
    return null;
  }

  StepsEditorState copyWith({
    StepsEditorStatus? status,
    String? projectName,
    StepPattern? pattern,
    StepsSaveStatus? save,
    DeletedStep? deleted,
    bool clearDeleted = false,
    bool? photoFailed,
  }) => StepsEditorState(
    status: status ?? this.status,
    projectName: projectName ?? this.projectName,
    pattern: pattern ?? this.pattern,
    save: save ?? this.save,
    deleted: clearDeleted ? null : (deleted ?? this.deleted),
    photoFailed: photoFailed ?? this.photoFailed,
  );

  @override
  List<Object?> get props => <Object?>[status, projectName, pattern, save, deleted, photoFailed];
}
