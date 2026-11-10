import 'dart:async';

import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/reading_order.dart';
import 'package:beading/domain/grid/word_chart.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/grid_pattern/grid_progress_store.dart';
import 'package:beading/domain/image_pattern/book_work/record_book_progress.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/change_project_status.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/settings_repository.dart';
import 'package:beading/domain/weaving/rows_counter.dart';
import 'package:beading/domain/weaving/work_session_tracker.dart';
import 'package:beading/presentation/weaving/weave_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Плетение по своей схеме: текущий ряд и бусина, отметки, учёт времени.
///
/// Каждое действие применяется на экране сразу, а на диск пишется следом, без задержки и по очереди: прогресс не
/// теряется при вылете. Номера рядов прогресса — ряды плетения ([ReadingOrder]).
class WeaveCubit extends Cubit<WeaveState> {
  WeaveCubit({
    required String projectId,
    required ProjectRepository projects,
    required GridPatternRepository patterns,
    required GridProgressStore progress,
    required SettingsRepository settings,
    required RecordBookProgress recordProgress,
    required ChangeProjectStatus changeStatus,
    required RowsCounter rowsCounter,
    required WorkSessionTracker tracker,
    this.toastDuration = const Duration(seconds: 4),
  }) : _projectId = projectId,
       _projects = projects,
       _patterns = patterns,
       _progress = progress,
       _settings = settings,
       _recordProgress = recordProgress,
       _changeStatus = changeStatus,
       _rowsCounter = rowsCounter,
       _tracker = tracker,
       super(const WeaveState());

  /// Сколько висит тост «Ряд готов · Отменить».
  final Duration toastDuration;

  final String _projectId;
  final ProjectRepository _projects;
  final GridPatternRepository _patterns;
  final GridProgressStore _progress;
  final SettingsRepository _settings;
  final RecordBookProgress _recordProgress;
  final ChangeProjectStatus _changeStatus;
  final RowsCounter _rowsCounter;
  final WorkSessionTracker _tracker;

  String? _patternId;
  Timer? _toastTimer;
  Future<void> _writes = Future<void>.value();

  Future<void> load() async {
    final Result<Project> project = await _projects.get(_projectId);
    final Result<GridPattern> pattern = await _patterns.getByProject(_projectId);
    if (isClosed) {
      return;
    }
    if (project.isFailure || pattern.isFailure) {
      emit(state.copyWith(status: WeaveStatus.failed));
      return;
    }
    final GridPattern found = pattern.valueOrNull!;
    final Result<GridProgress> saved = await _progress.load(found.id);
    final Result<bool> byBead = await _settings.read<bool>(SettingKeys.weaveByBead);
    final Result<bool> symbols = await _settings.read<bool>(SettingKeys.symbolMode);
    if (isClosed) {
      return;
    }
    if (saved.isFailure) {
      emit(state.copyWith(status: WeaveStatus.failed));
      return;
    }
    _patternId = found.id;
    final ReadingOrder order = ReadingOrder.of(found.geometry, columns: found.grid.width, rows: found.grid.height);
    final GridProgress progress = saved.valueOrNull!;
    final Set<int> done = <int>{
      for (final int r in progress.completedRows)
        if (r < order.rowCount) r,
    };
    int row = progress.currentRow ?? _firstOpen(done, order.rowCount);
    if (row >= order.rowCount) {
      row = order.rowCount - 1;
    }
    final WeaveMode mode = (byBead.valueOrNull ?? false) ? WeaveMode.byBead : WeaveMode.byRow;
    final WeaveState base = state.copyWith(
      status: WeaveStatus.ready,
      projectName: project.valueOrNull!.name,
      projectDone: project.valueOrNull!.status == ProjectStatus.done,
      pattern: found,
      order: order,
      mode: mode,
      showSymbols: symbols.valueOrNull ?? false,
      completedRows: done,
    );
    final WeaveState rowState = _atRow(base, row, 0);
    final int laid = mode == WeaveMode.byBead ? (progress.currentBead ?? 0).clamp(0, _maxLaid(rowState)) : 0;
    emit(rowState.copyWith(laid: laid));
    unawaited(_tracker.start(_projectId));
  }

  int _firstOpen(Set<int> done, int count) {
    for (int i = 0; i < count; i++) {
      if (!done.contains(i)) {
        return i;
      }
    }
    return count - 1;
  }

  /// Наибольшее число выложенных бусин, при котором ряд ещё не закончен.
  int _maxLaid(WeaveState s) => s.beadCount == 0 ? 0 : s.beadCount - 1;

  WeaveState _atRow(WeaveState from, int row, int laid) {
    final GridPattern pattern = from.pattern!;
    final ReadingRow reading = from.order!.row(row);
    final List<CellPosition> beads = <CellPosition>[
      for (final CellPosition c in reading.cells)
        if (pattern.grid.at(c.column, c.row) != 0) c,
    ];
    return from.copyWith(
      row: row,
      laid: laid,
      cells: reading.cells,
      beadCells: beads,
      direction: reading.direction,
      runs: WordChart.forRow(pattern.grid, reading),
    );
  }

  /// Переключает «по ряду» / «по бусине»; выбор запоминается.
  void setMode(WeaveMode mode) {
    if (!state.isReady || mode == state.mode) {
      return;
    }
    emit(state.copyWith(mode: mode, laid: 0, clearToast: true));
    _enqueue(() async {
      final bool a = (await _settings.write<bool>(SettingKeys.weaveByBead, mode == WeaveMode.byBead)).isFailure;
      final bool b = await _saveCurrent();
      return a || b;
    });
  }

  void toggleSymbols() {
    if (state.isReady) {
      emit(state.copyWith(showSymbols: !state.showSymbols));
    }
  }

  /// Выложена следующая бусина. Последняя бусина ряда завершает ряд. Только «по бусине».
  void nextBead() {
    if (!state.isReady || state.mode != WeaveMode.byBead || state.allDone) {
      return;
    }
    if (state.laid + 1 >= state.beadCount) {
      completeRow();
      return;
    }
    emit(state.copyWith(laid: state.laid + 1, clearToast: true));
    _enqueue(() async => _moved(await _saveCurrent()));
  }

  /// «Дальше»: «по бусине» — следующая бусина, «по ряду» — ряд готов.
  void stepForward() => state.mode == WeaveMode.byBead ? nextBead() : completeRow();

  /// Ряд готов: отмечается целиком, текущим становится следующий.
  void completeRow() {
    if (!state.isReady || state.allDone && state.completedRows.contains(state.row)) {
      return;
    }
    final int finished = state.row;
    final bool fresh = !state.completedRows.contains(finished);
    final Set<int> done = <int>{...state.completedRows, finished};
    final bool last = finished >= state.rowCount - 1;
    final WeaveState next = last
        ? state.copyWith(completedRows: done, laid: 0)
        : _atRow(state.copyWith(completedRows: done), finished + 1, 0);
    final bool finishedAll = done.length >= state.rowCount;
    emit(
      next.copyWith(
        toastRow: finished,
        completions: state.completions + 1,
        offerFinish: finishedAll && !state.projectDone,
      ),
    );
    _restartToastTimer();
    _enqueue(() async {
      final bool a = (await _progress.markRow(_patternId!, finished)).isFailure;
      final bool b = await _saveCurrent();
      if (!a && fresh) {
        await _rowsCounter.completed();
      }
      return _moved(a || b);
    });
  }

  /// Шаг назад: сначала отменяет выложенные бусины ряда, потом снимает отметку с прошлого ряда.
  void back() {
    if (!state.isReady || !state.canGoBack) {
      return;
    }
    final bool byBead = state.mode == WeaveMode.byBead;
    if (state.laid > 0) {
      emit(state.copyWith(laid: state.laid - 1, clearToast: true));
      _enqueue(() async => _moved(await _saveCurrent()));
      return;
    }
    // Последний ряд уже отмечен, текущим остался он же.
    final int reopened = state.completedRows.contains(state.row) ? state.row : state.row - 1;
    final Set<int> done = <int>{...state.completedRows}..remove(reopened);
    WeaveState next = reopened == state.row ? state : _atRow(state, reopened, 0);
    next = next.copyWith(completedRows: done, clearToast: true, offerFinish: false);
    emit(next.copyWith(laid: byBead ? _maxLaid(next) : 0));
    _enqueue(() async {
      final bool a = (await _progress.unmarkRow(_patternId!, reopened)).isFailure;
      final bool b = await _saveCurrent();
      await _rowsCounter.undone();
      return a || b;
    });
  }

  /// Тост «Отменить».
  void undoCompletion() => back();

  void dismissToast() {
    _toastTimer?.cancel();
    if (state.toastRow != null) {
      emit(state.copyWith(clearToast: true));
    }
  }

  /// Проект отмечен готовым (по предложению на последнем ряду).
  Future<void> finishProject() async {
    emit(state.copyWith(offerFinish: false));
    final Result<Project> changed = await _changeStatus(_projectId, ProjectStatus.done);
    if (!isClosed && changed.isSuccess) {
      emit(state.copyWith(projectDone: true));
    }
  }

  void dismissFinish() {
    if (state.offerFinish) {
      emit(state.copyWith(offerFinish: false));
    }
  }

  /// Приложение ушло в фон: время перестаёт идти.
  Future<void> pause() => _tracker.pause();

  Future<void> resume() => _tracker.resume();

  void _restartToastTimer() {
    _toastTimer?.cancel();
    _toastTimer = Timer(toastDuration, dismissToast);
  }

  Future<bool> _saveCurrent() async {
    final WeaveState s = state;
    final Result<void> saved = await _progress.setCurrent(
      _patternId!,
      row: s.row,
      bead: s.mode == WeaveMode.byBead && s.laid > 0 ? s.laid : null,
    );
    return saved.isFailure;
  }

  /// Работа сдвинулась: проект «идея» становится «в работе». Возвращает, не сорвалась ли запись.
  Future<bool> _moved(bool failed) async {
    final Result<Project> recorded = await _recordProgress(_projectId);
    return failed || recorded.isFailure;
  }

  /// Записи идут по очереди; провал показывается, пока не пройдёт следующая запись.
  void _enqueue(Future<bool> Function() write) {
    _writes = _writes.then((_) async {
      bool failed;
      try {
        failed = await write();
      } on Object {
        failed = true;
      }
      if (!isClosed && failed != state.saveFailed) {
        emit(state.copyWith(saveFailed: failed));
      }
    });
  }

  @override
  Future<void> close() async {
    _toastTimer?.cancel();
    try {
      await _writes;
      await _tracker.stop();
    } finally {
      await super.close();
    }
  }
}
