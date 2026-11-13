import 'dart:async';

import 'package:beading/core/result.dart';
import 'package:beading/domain/editor/cell_rect.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/domain/grid_pattern/cell_progress_store.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/grid_pattern/grid_progress_store.dart';
import 'package:beading/domain/grid_pattern/stitch_counters.dart';
import 'package:beading/domain/grid_pattern/use_cases/cell_progress_commands.dart';
import 'package:beading/domain/image_pattern/book_work/record_book_progress.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/change_project_status.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/settings_repository.dart';
import 'package:beading/domain/weaving/work_session_tracker.dart';
import 'package:beading/presentation/stitching/stitch_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Режим вышивания: отметка клеток касанием, мазком, областью и по цвету, счётчики, парковка, учёт времени.
///
/// Каждая отметка сразу видна на экране, а на диск пишется следом и по очереди (как в плетении): прогресс не теряется при
/// вылете. Мазок и область пишутся один раз, когда палец оторван.
class StitchCubit extends Cubit<StitchState> {
  StitchCubit({
    required String projectId,
    required ProjectRepository projects,
    required GridPatternRepository patterns,
    required CellProgressStore cellProgress,
    required GridProgressStore progress,
    required MarkCells markCells,
    required MarkRect markRect,
    required MarkColor markColor,
    required SettingsRepository settings,
    required RecordBookProgress recordProgress,
    required ChangeProjectStatus changeStatus,
    required WorkSessionTracker tracker,
    required AppEvents events,
  }) : _projectId = projectId,
       _projects = projects,
       _patterns = patterns,
       _cellProgress = cellProgress,
       _progress = progress,
       _markCells = markCells,
       _markRect = markRect,
       _markColor = markColor,
       _settings = settings,
       _recordProgress = recordProgress,
       _changeStatus = changeStatus,
       _tracker = tracker,
       _events = events,
       super(const StitchState());

  final String _projectId;
  final ProjectRepository _projects;
  final GridPatternRepository _patterns;
  final CellProgressStore _cellProgress;
  final GridProgressStore _progress;
  final MarkCells _markCells;
  final MarkRect _markRect;
  final MarkColor _markColor;
  final SettingsRepository _settings;
  final RecordBookProgress _recordProgress;
  final ChangeProjectStatus _changeStatus;
  final WorkSessionTracker _tracker;
  final AppEvents _events;

  String? _patternId;
  Future<void> _writes = Future<void>.value();

  // Откат: последние действия с клетками, которые они реально изменили.
  static const int _historyLimit = 30;
  static const Duration _noticeTime = Duration(seconds: 5);
  final List<({List<CellPosition> cells, bool done})> _history = <({List<CellPosition> cells, bool done})>[];
  Timer? _noticeTimer;

  // Мазок.
  bool _stroking = false;
  bool _strokeDone = true;
  final List<CellPosition> _strokeCells = <CellPosition>[];
  final List<CellPosition> _strokeChanged = <CellPosition>[];

  Future<void> load() async {
    final Result<Project> project = await _projects.get(_projectId);
    final Result<GridPattern> pattern = await _patterns.getByProject(_projectId);
    if (isClosed) {
      return;
    }
    if (project.isFailure || pattern.isFailure) {
      emit(state.copyWith(status: StitchStatus.failed));
      return;
    }
    final GridPattern loaded = pattern.valueOrNull!;
    // Мелкие и похожие знаки старых схем заменяем только на показе.
    final GridPattern found = loaded.copyWith(palette: loaded.palette.withLegibleSymbols());
    final Result<CellProgress> cells = await _cellProgress.load(found.id);
    final Result<GridProgress> rows = await _progress.load(found.id);
    final Result<bool> symbols = await _settings.read<bool>(SettingKeys.symbolMode);
    if (isClosed) {
      return;
    }
    if (cells.isFailure || rows.isFailure) {
      emit(state.copyWith(status: StitchStatus.failed));
      return;
    }
    _patternId = found.id;
    final GridProgress saved = rows.valueOrNull!;
    final int? parkedRow = saved.currentRow;
    final int? parkedColumn = saved.currentBead;
    final CellPosition? parked =
        parkedRow != null && parkedColumn != null && parkedRow < found.grid.height && parkedColumn < found.grid.width
        ? CellPosition(parkedColumn, parkedRow)
        : null;
    emit(
      _recount(
        state.copyWith(
          status: StitchStatus.ready,
          projectName: project.valueOrNull!.name,
          projectDone: project.valueOrNull!.status == ProjectStatus.done,
          pattern: found,
          progress: cells.valueOrNull,
          showSymbols: symbols.valueOrNull ?? false,
          parked: parked,
        ),
      ),
    );
    unawaited(_tracker.start(_projectId));
  }

  /// Пересчитывает счётчики по цветам, по блокам и общий.
  StitchState _recount(StitchState s) {
    final Grid grid = s.pattern!.grid;
    final StitchTally tally = StitchCounters.tally(grid, s.progress, paletteSize: s.pattern!.palette.colors.length);
    return s.copyWith(byColor: tally.byColor, blocks: tally.blocks, total: tally.total, done: tally.done);
  }

  void setTool(StitchTool tool) {
    if (state.isReady && tool != state.tool) {
      emit(state.copyWith(tool: tool, clearAreaPreview: true));
    }
  }

  void toggleSymbols() {
    if (state.isReady) {
      emit(state.copyWith(showSymbols: !state.showSymbols));
    }
  }

  void toggleBlocks() {
    if (state.isReady) {
      emit(state.copyWith(showBlocks: !state.showBlocks));
    }
  }

  /// Подсвечивает цвет (значение сетки с 1); повторный выбор снимает подсветку.
  void highlight(int? value) {
    if (!state.isReady) {
      return;
    }
    emit(
      value == null || value == state.highlight
          ? state.copyWith(clearHighlight: true)
          : state.copyWith(highlight: value),
    );
  }

  bool _isStitch(CellPosition c) {
    final Grid grid = state.pattern!.grid;
    return c.column >= 0 && c.row >= 0 && c.column < grid.width && c.row < grid.height && grid.at(c.column, c.row) != 0;
  }

  /// Касание клетки: сделана — снимает отметку, нет — отмечает. Пустые клетки не отмечаются.
  void tapCell(CellPosition cell) {
    if (!state.isReady || !_isStitch(cell)) {
      return;
    }
    final bool done = !state.progress.isDone(cell.column, cell.row);
    _apply(<CellPosition>[cell], done: done);
    _enqueue(() async => (await _markCells(projectId: _projectId, cells: <CellPosition>[cell], done: done)).isFailure);
  }

  // Мазок: первая клетка выбирает, отмечаем мы или снимаем отметки на всём мазке.
  void strokeStart() {
    _stroking = true;
    _strokeCells.clear();
    _strokeChanged.clear();
  }

  void strokeCell(CellPosition cell) {
    if (!state.isReady || !_stroking || !_isStitch(cell) || _strokeCells.contains(cell)) {
      return;
    }
    if (_strokeCells.isEmpty) {
      _strokeDone = !state.progress.isDone(cell.column, cell.row);
    }
    if (state.progress.isDone(cell.column, cell.row) != _strokeDone) {
      _strokeChanged.add(cell);
    }
    _strokeCells.add(cell);
    // Во время мазка обновляем только отметки: счётчики пересчитаем, когда палец оторвётся.
    emit(state.copyWith(progress: state.progress.withCells(<CellPosition>[cell], done: _strokeDone)));
  }

  void strokeEnd() {
    if (!_stroking) {
      return;
    }
    _stroking = false;
    if (_strokeCells.isEmpty) {
      return;
    }
    final List<CellPosition> cells = List<CellPosition>.of(_strokeCells);
    final bool done = _strokeDone;
    _strokeCells.clear();
    _afterChange(done: done, touched: cells);
    _record(List<CellPosition>.of(_strokeChanged), done: done);
    _enqueue(() async => (await _markCells(projectId: _projectId, cells: cells, done: done)).isFailure);
  }

  /// Область: угол нажатия и текущая клетка; рамка видна, пока палец на экране.
  void areaDrag(CellPosition anchor, CellPosition current) {
    if (!state.isReady) {
      return;
    }
    emit(state.copyWith(areaPreview: CellRect.fromCorners(anchor, current)));
  }

  /// Палец оторван: область отмечается, а если в ней всё уже сделано — отметки снимаются.
  void areaEnd() {
    final CellRect? rect = state.areaPreview;
    if (!state.isReady || rect == null) {
      return;
    }
    emit(state.copyWith(clearAreaPreview: true));
    final Grid grid = state.pattern!.grid;
    final CellRect? clipped = rect.clipTo(grid);
    if (clipped == null) {
      return;
    }
    final List<CellPosition> cells = <CellPosition>[
      for (int r = clipped.top; r <= clipped.bottom; r++)
        for (int c = clipped.left; c <= clipped.right; c++)
          if (grid.at(c, r) != 0) CellPosition(c, r),
    ];
    if (cells.isEmpty) {
      return;
    }
    final bool done = cells.any((c) => !state.progress.isDone(c.column, c.row));
    _apply(cells, done: done);
    _enqueue(() async => (await _markRect(projectId: _projectId, rect: clipped, done: done)).isFailure);
  }

  /// Все клетки цвета [color] (номер в палитре с нуля): сделаны или сняты. Если всё уже сделано, отметки снимаются.
  void markColor(int color) {
    if (!state.isReady || color < 0 || color >= state.byColor.length) {
      return;
    }
    final ColorCount count = state.byColor[color];
    if (count.total == 0) {
      return;
    }
    final bool done = count.remaining > 0;
    final Grid grid = state.pattern!.grid;
    final List<CellPosition> cells = <CellPosition>[
      for (int r = 0; r < grid.height; r++)
        for (int c = 0; c < grid.width; c++)
          if (grid.at(c, r) == color + 1) CellPosition(c, r),
    ];
    _apply(cells, done: done);
    _enqueue(() async => (await _markColor(projectId: _projectId, color: color, done: done)).isFailure);
  }

  /// Парковка: запоминает клетку, на которой остановились.
  void park(CellPosition cell) {
    if (!state.isReady || cell.column < 0 || cell.row < 0) {
      return;
    }
    final Grid grid = state.pattern!.grid;
    if (cell.column >= grid.width || cell.row >= grid.height) {
      return;
    }
    // Долгое касание по уже запомненной клетке снимает метку.
    if (state.parked == cell) {
      clearParked();
      return;
    }
    emit(state.copyWith(parked: cell));
    _enqueue(() async => (await _progress.setCurrent(_patternId!, row: cell.row, bead: cell.column)).isFailure);
  }

  /// Снимает метку места остановки.
  void clearParked() {
    if (!state.isReady || state.parked == null) {
      return;
    }
    emit(state.copyWith(clearParked: true));
    _enqueue(() async => (await _progress.clearCurrent(_patternId!)).isFailure);
  }

  /// Применяет отметку на экране, пересчитывает счётчики и сообщает пасхалкам о закрытых блоках и цветах.
  void _apply(List<CellPosition> cells, {required bool done}) {
    final List<CellPosition> changed = <CellPosition>[
      for (final CellPosition c in cells)
        if (state.progress.isDone(c.column, c.row) != done) c,
    ];
    emit(state.copyWith(progress: state.progress.withCells(cells, done: done)));
    _afterChange(done: done, touched: cells);
    _record(changed, done: done);
  }

  /// Запоминает действие для отката. После мазка, области и цвета целиком (больше одной клетки) показывается тост.
  void _record(List<CellPosition> changed, {required bool done}) {
    if (changed.isEmpty) {
      return;
    }
    _history.add((cells: changed, done: done));
    if (_history.length > _historyLimit) {
      _history.removeAt(0);
    }
    _noticeTimer?.cancel();
    if (changed.length > 1) {
      emit(state.copyWith(canUndo: true, undoNotice: (count: changed.length, done: done)));
      _noticeTimer = Timer(_noticeTime, () {
        if (!isClosed) {
          emit(state.copyWith(clearUndoNotice: true));
        }
      });
    } else {
      emit(state.copyWith(canUndo: true, clearUndoNotice: true));
    }
  }

  /// Откатывает последнее действие целиком: мазок, область, цвет или касание.
  void undo() {
    if (!state.isReady || _stroking || _history.isEmpty) {
      return;
    }
    _noticeTimer?.cancel();
    final ({List<CellPosition> cells, bool done}) last = _history.removeLast();
    final bool done = !last.done;
    emit(state.copyWith(progress: state.progress.withCells(last.cells, done: done)));
    _afterChange(done: done, touched: last.cells);
    emit(state.copyWith(canUndo: _history.isNotEmpty, clearUndoNotice: true));
    _enqueue(() async => (await _markCells(projectId: _projectId, cells: last.cells, done: done)).isFailure);
  }

  /// Скрывает тост, не откатывая.
  void dismissUndoNotice() {
    if (state.undoNotice != null) {
      _noticeTimer?.cancel();
      emit(state.copyWith(clearUndoNotice: true));
    }
  }

  void _afterChange({required bool done, required List<CellPosition> touched}) {
    final StitchState before = state;
    final CellPosition? parked = state.parked;
    // Дошла до запомненной клетки и сделала её: метка больше не нужна.
    if (done && parked != null && touched.contains(parked)) {
      clearParked();
    }
    final StitchState counted = _recount(state);
    final int closedBlocks = counted.blocks.where((b) => b.isComplete).length;
    final int wasClosed = before.blocks.where((b) => b.isComplete).length;
    emit(
      counted.copyWith(
        marks: state.marks + 1,
        offerFinish: done && counted.allDone && !before.allDone && !state.projectDone,
      ),
    );
    if (!done) {
      return;
    }
    if (closedBlocks > wasClosed) {
      _events.publish(StitchBlockCompleted(projectId: _projectId, total: closedBlocks));
    }
    final Set<int> colors = <int>{
      for (final CellPosition c in touched) state.pattern!.grid.at(c.column, c.row) - 1,
    };
    for (final int color in colors) {
      final bool wasOpen = color < before.byColor.length && before.byColor[color].remaining > 0;
      if (wasOpen && counted.byColor[color].remaining == 0) {
        _events.publish(StitchColorCompleted(_projectId));
      }
    }
  }

  /// Проект отмечен готовым (по предложению, когда все клетки сделаны).
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

  /// Записи идут по очереди; провал показывается, пока не пройдёт следующая запись. Работа сдвинулась: проект
  /// «идея» становится «в работе».
  void _enqueue(Future<bool> Function() write) {
    _writes = _writes.then((_) async {
      bool failed;
      try {
        failed = await write();
        if (!failed) {
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

  @override
  Future<void> close() async {
    _noticeTimer?.cancel();
    try {
      await _writes;
      await _tracker.stop();
    } finally {
      await super.close();
    }
  }
}
