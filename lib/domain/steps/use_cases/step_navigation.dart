import 'package:beading/core/result.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/step_pattern_repository.dart';
import 'package:beading/domain/steps/steps_progress.dart';

/// Читает и двигает курсор прогресса. Новое положение сразу записывается.
class StepNavigation {
  const StepNavigation(this._store);

  final StepsProgressStore _store;

  /// Сохранённое положение или начало, если работу не начинали.
  Future<Result<StepsProgress>> current(StepPattern pattern) async {
    final Result<StepsProgress?> loaded = await _store.load(pattern.id);
    return loaded.map((p) => p ?? StepsProgress.start(pattern));
  }

  Future<Result<StepsProgress>> next(StepPattern pattern) => _move(pattern, (p) => p.next(pattern));

  /// «Достаточно» для повторов «до нужной длины».
  Future<Result<StepsProgress>> skipRepeat(StepPattern pattern) => _move(pattern, (p) => p.skipRepeat(pattern));

  Future<Result<StepsProgress>> previous(StepPattern pattern) => _move(pattern, (p) => p.previous(pattern));

  /// Касание шага в списке.
  Future<Result<StepsProgress>> jumpTo(StepPattern pattern, String stepId) =>
      _move(pattern, (p) => p.jumpTo(pattern, stepId));

  /// После правки инструкции: курсор под удалённым шагом уходит на ближайший оставшийся.
  Future<Result<StepsProgress>> reconcile({required StepPattern before, required StepPattern after}) async {
    final Result<StepsProgress?> loaded = await _store.load(after.id);
    if (loaded case Err<StepsProgress?>(:final failure)) {
      return Err<StepsProgress>(failure);
    }
    final StepsProgress? saved = loaded.valueOrNull;
    if (saved == null) {
      return Success<StepsProgress>(StepsProgress.start(after)); // работу не начинали: записывать нечего
    }
    return _move(after, (p) => p.reconcile(before: before, after: after));
  }

  Future<Result<StepsProgress>> _move(StepPattern pattern, StepsProgress Function(StepsProgress) step) async {
    final Result<StepsProgress> now = await current(pattern);
    if (now case Err<StepsProgress>()) {
      return now;
    }
    final StepsProgress moved = step(now.valueOrNull!);
    final Result<void> saved = await _store.save(pattern.id, moved);
    return saved.map((_) => moved);
  }
}
