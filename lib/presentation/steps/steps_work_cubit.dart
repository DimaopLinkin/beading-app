import 'dart:async';

import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/book_work/record_book_progress.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/change_project_status.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/step_pattern_repository.dart';
import 'package:beading/domain/steps/steps_progress.dart';
import 'package:beading/domain/steps/use_cases/step_navigation.dart';
import 'package:beading/domain/weaving/work_session_tracker.dart';
import 'package:beading/presentation/steps/steps_work_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Работа по пошаговой инструкции: «Готово, дальше», «Назад», «Достаточно», переход по списку, учёт времени.
///
/// Каждое движение курсора записывается сразу и по очереди, поэтому после вылета мастерица возвращается на тот же шаг.
class StepsWorkCubit extends Cubit<StepsWorkState> {
  StepsWorkCubit({
    required String projectId,
    required ProjectRepository projects,
    required StepPatternRepository patterns,
    required StepNavigation navigation,
    required RecordBookProgress recordProgress,
    required ChangeProjectStatus changeStatus,
    required WorkSessionTracker tracker,
  }) : _projectId = projectId,
       _projects = projects,
       _patterns = patterns,
       _navigation = navigation,
       _recordProgress = recordProgress,
       _changeStatus = changeStatus,
       _tracker = tracker,
       super(const StepsWorkState());

  final String _projectId;
  final ProjectRepository _projects;
  final StepPatternRepository _patterns;
  final StepNavigation _navigation;
  final RecordBookProgress _recordProgress;
  final ChangeProjectStatus _changeStatus;
  final WorkSessionTracker _tracker;

  Future<void> _writes = Future<void>.value();

  Future<void> load() async {
    final Result<Project> project = await _projects.get(_projectId);
    final Result<StepPattern> pattern = await _patterns.getByProject(_projectId);
    if (isClosed) {
      return;
    }
    if (project.isFailure || pattern.isFailure) {
      emit(state.copyWith(status: StepsWorkStatus.failed));
      return;
    }
    final Result<StepsProgress> progress = await _navigation.current(pattern.valueOrNull!);
    if (isClosed) {
      return;
    }
    if (progress.isFailure) {
      emit(state.copyWith(status: StepsWorkStatus.failed));
      return;
    }
    final StepPattern found = pattern.valueOrNull!;
    StepsProgress at = progress.valueOrNull!;
    if (!at.finished && !_hasStep(found, at)) {
      at = StepsProgress.start(found); // курсор на удалённом шаге (правка на другом устройстве): начинаем сначала
    }
    emit(
      state.copyWith(
        status: StepsWorkStatus.ready,
        projectName: project.valueOrNull!.name,
        projectDone: project.valueOrNull!.status == ProjectStatus.done,
        pattern: found,
        progress: at,
      ),
    );
    unawaited(_tracker.start(_projectId));
  }

  static bool _hasStep(StepPattern pattern, StepsProgress progress) => pattern.sections.any(
    (s) => s.id == progress.sectionId && s.steps.any((st) => st.id == progress.stepId),
  );

  /// «Готово, дальше». На последнем шаге работа заканчивается: проект при этом не меняется, это отдельная кнопка.
  void next() => _move(_navigation.next);

  /// «Достаточно» для повторов «до нужной длины».
  void skipRepeat() => _move(_navigation.skipRepeat);

  void back() => _move(_navigation.previous);

  /// Касание шага в списке.
  void jumpTo(String stepId) => _move((p) => _navigation.jumpTo(p, stepId));

  bool _finishing = false;

  /// «Работа закончена»: курсор уходит за последний шаг (если ещё не там), проект отмечается готовым.
  /// У проекта, уже отмеченного готовым, статус не трогаем.
  Future<void> finishWork() async {
    if (!state.isReady || state.isEmpty || _finishing) {
      return;
    }
    _finishing = true;
    try {
      if (!state.finished) {
        _move(_navigation.skipRepeat); // на последнем шаге то же, что next, а «до нужной длины» заканчивает
      }
      await _writes;
      if (state.projectDone || isClosed) {
        return;
      }
      final Result<Project> changed = await _changeStatus(_projectId, ProjectStatus.done);
      if (isClosed) {
        return;
      }
      emit(changed.isSuccess ? state.copyWith(projectDone: true) : state.copyWith(saveFailed: true));
    } finally {
      _finishing = false;
    }
  }

  void _move(Future<Result<StepsProgress>> Function(StepPattern pattern) move) {
    if (!state.isReady || state.isEmpty) {
      return;
    }
    _writes = _writes.then((_) async {
      bool failed;
      try {
        final Result<StepsProgress> moved = await move(state.pattern!);
        failed = moved.isFailure;
        if (moved.isSuccess && !isClosed) {
          emit(state.copyWith(progress: moved.valueOrNull, saveFailed: false));
          failed = (await _recordProgress(_projectId)).isFailure;
        }
      } on Object {
        failed = true;
      }
      if (!isClosed && failed != state.saveFailed) {
        emit(state.copyWith(saveFailed: failed));
      }
    });
  }

  /// Приложение ушло в фон: время перестаёт идти.
  Future<void> pause() => _tracker.pause();

  Future<void> resume() => _tracker.resume();

  @override
  Future<void> close() async {
    try {
      await _writes;
      await _tracker.stop();
    } finally {
      await super.close();
    }
  }
}
