import 'dart:async';
import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:beading/domain/editor/cell_line.dart';
import 'package:beading/domain/editor/cell_rect.dart';
import 'package:beading/domain/editor/editor_commands.dart';
import 'package:beading/domain/editor/undo_stack.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/use_cases/save_grid_pattern.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:beading/presentation/editor/editor_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Редактор сеточной схемы: инструменты, палитра, отмена и автосохранение.
///
/// Правки применяются к экрану сразу, а на диск пишутся с паузой [saveDelay] (debounce) и обязательно при закрытии.
/// Мазок кистью — один шаг отмены. Палитровые правки, которые переписывают сетку (удаление цвета), обнуляют историю:
/// старые снимки сетки не подходят к новой палитре.
class EditorCubit extends Cubit<EditorState> {
  EditorCubit({
    required String projectId,
    required ProjectRepository projects,
    required GridPatternRepository patterns,
    required SaveGridPattern savePattern,
    required TouchProject touchProject,
    this.saveDelay = const Duration(milliseconds: 400),
  }) : _projectId = projectId,
       _projects = projects,
       _patterns = patterns,
       _savePattern = savePattern,
       _touchProject = touchProject,
       super(const EditorState());

  final Duration saveDelay;

  final String _projectId;
  final ProjectRepository _projects;
  final GridPatternRepository _patterns;
  final SaveGridPattern _savePattern;
  final TouchProject _touchProject;

  UndoStack? _undo;
  Timer? _timer;
  Future<void> _saving = Future<void>.value();
  bool _dirty = false;
  bool _stroking = false;
  CellPosition? _lastStrokeCell;

  GridPattern get _pattern => state.pattern!;

  Future<void> load() async {
    final Result<Project> project = await _projects.get(_projectId);
    final Result<GridPattern> pattern = await _patterns.getByProject(_projectId);
    if (isClosed) return;
    if (project case Success<Project>(:final Project value) when pattern is Success<GridPattern>) {
      final GridPattern loaded = pattern.valueOrNull!;
      _undo = UndoStack(loaded.grid);
      emit(
        state.copyWith(
          status: EditorStatus.ready,
          projectName: value.name,
          pattern: loaded,
          activeColor: loaded.palette.length > 0 ? 1 : 0,
        ),
      );
      return;
    }
    emit(state.copyWith(status: EditorStatus.loadFailed));
  }

  // --- инструменты ------------------------------------------------------------------------------------------------

  void selectTool(EditorTool tool) {
    if (state.status != EditorStatus.ready) return;
    emit(state.copyWith(tool: tool, clearProblem: true, clearSelection: tool != EditorTool.selection));
  }

  void selectColor(int gridValue) {
    if (state.status != EditorStatus.ready || state.pattern!.palette.colorAt(gridValue) == null) return;
    // Выбрав цвет после ластика, возвращаемся к кисти: иначе цвет «не работает».
    final EditorTool tool = state.tool == EditorTool.eraser || state.tool == EditorTool.pipette
        ? EditorTool.brush
        : state.tool;
    emit(state.copyWith(activeColor: gridValue, tool: tool, clearProblem: true));
  }

  void toggleSymbols() => emit(state.copyWith(showSymbols: !state.showSymbols));

  void dismissProblem() => emit(state.copyWith(clearProblem: true));

  // --- рисование --------------------------------------------------------------------------------------------------

  /// Касание ячейки одиночным нажатием: действие зависит от инструмента.
  void tapCell(CellPosition cell) {
    if (state.status != EditorStatus.ready) return;
    emit(state.copyWith(focus: cell));
    switch (state.tool) {
      case EditorTool.brush:
      case EditorTool.eraser:
        beginStroke();
        strokeTo(cell);
        endStroke();
      case EditorTool.fill:
        _fill(cell);
      case EditorTool.pipette:
        _pick(cell);
      case EditorTool.replaceColor:
        _replace(cell);
      case EditorTool.selection:
        emit(state.copyWith(selection: CellRect.fromCorners(cell, cell)));
    }
  }

  /// Начало мазка кистью или ластиком: до [endStroke] все ячейки — один шаг отмены.
  void beginStroke() {
    if (state.status != EditorStatus.ready || _stroking) return;
    if (state.tool == EditorTool.selection) return;
    if (state.tool == EditorTool.brush && state.activeColor == 0) {
      emit(state.copyWith(problem: EditorProblem.noColor));
      return;
    }
    _stroking = true;
    _lastStrokeCell = null;
    _undo!.beginGroup();
  }

  /// Ячейка мазка. Пропущенные быстрым движением ячейки между прошлым и этим касанием дорисовываются отрезком.
  void strokeTo(CellPosition cell) {
    if (!_stroking) return;
    final CellPosition? previous = _lastStrokeCell;
    _lastStrokeCell = cell;
    final Iterable<CellPosition> cells = previous == null ? <CellPosition>[cell] : cellLine(previous, cell);
    final int value = state.tool == EditorTool.eraser ? 0 : state.activeColor;
    final Grid next = EditorCommands.paint(_pattern.grid, cells, value, within: state.selection);
    _applyGrid(next, focus: cell);
  }

  void endStroke() {
    if (!_stroking) return;
    _stroking = false;
    _lastStrokeCell = null;
    _undo!.endGroup();
  }

  void _fill(CellPosition cell) {
    if (state.activeColor == 0) {
      emit(state.copyWith(problem: EditorProblem.noColor));
      return;
    }
    _applyGrid(
      EditorCommands.floodFill(_pattern.grid, _pattern.geometry, cell, state.activeColor, within: state.selection),
    );
  }

  void _pick(CellPosition cell) {
    final int? value = EditorCommands.pick(_pattern.grid, cell);
    if (value == null) return;
    // Пустая ячейка: пипетка включает ластик, как в большинстве редакторов.
    emit(
      value == 0
          ? state.copyWith(tool: EditorTool.eraser, clearProblem: true)
          : state.copyWith(activeColor: value, tool: EditorTool.brush, clearProblem: true),
    );
  }

  void _replace(CellPosition cell) {
    final int? from = EditorCommands.pick(_pattern.grid, cell);
    if (from == null || from == 0) return;
    if (state.activeColor == 0) {
      emit(state.copyWith(problem: EditorProblem.noColor));
      return;
    }
    _applyGrid(EditorCommands.replaceColor(_pattern.grid, from, state.activeColor, within: state.selection));
  }

  // --- выделение и преобразования ---------------------------------------------------------------------------------

  void selectRect(CellPosition a, CellPosition b) {
    if (state.status != EditorStatus.ready) return;
    emit(state.copyWith(selection: CellRect.fromCorners(a, b), focus: b));
  }

  void clearSelection() => emit(state.copyWith(clearSelection: true));

  /// Зеркало по горизонтали для выделения (или всей схемы). Для мозаики и кирпичика зеркалятся индексы ячеек, а не
  /// физическая раскладка: экран говорит об этом.
  void mirrorHorizontal() => _applyGrid(EditorCommands.mirrorHorizontal(_pattern.grid, within: state.selection));

  void mirrorVertical() => _applyGrid(EditorCommands.mirrorVertical(_pattern.grid, within: state.selection));

  void insertRow(int at) => _applyResult(EditorCommands.insertRow(_pattern.grid, at));

  void deleteRow(int at) => _applyResult(EditorCommands.deleteRow(_pattern.grid, at));

  void insertColumn(int at) => _applyResult(EditorCommands.insertColumn(_pattern.grid, at));

  void deleteColumn(int at) => _applyResult(EditorCommands.deleteColumn(_pattern.grid, at));

  void _applyResult(Result<Grid> result) {
    switch (result) {
      case Success<Grid>(:final Grid value):
        // Форма меняется: выделение и фокус больше не указывают на те же ячейки.
        _applyGrid(value, resetView: true);
      case Err<Grid>():
        final bool atLimit = result.failureOrNull!.message.contains('максимум');
        emit(state.copyWith(problem: atLimit ? EditorProblem.limitReached : EditorProblem.lastRowOrColumn));
    }
  }

  // --- отмена -----------------------------------------------------------------------------------------------------

  void undo() {
    final Grid? grid = _undo?.undo();
    if (grid != null) _afterHistory(grid);
  }

  void redo() {
    final Grid? grid = _undo?.redo();
    if (grid != null) _afterHistory(grid);
  }

  void _afterHistory(Grid grid) {
    _stroking = false;
    final bool shapeChanged = grid.width != _pattern.grid.width || grid.height != _pattern.grid.height;
    emit(
      state.copyWith(
        pattern: _pattern.copyWith(grid: grid),
        canUndo: _undo!.canUndo,
        canRedo: _undo!.canRedo,
        clearSelection: shapeChanged,
        clearFocus: shapeChanged,
        clearProblem: true,
      ),
    );
    _markDirty();
  }

  void _applyGrid(Grid next, {CellPosition? focus, bool resetView = false}) {
    if (next == _pattern.grid) return;
    _undo!.apply(next);
    emit(
      state.copyWith(
        pattern: _pattern.copyWith(grid: next),
        canUndo: _undo!.canUndo,
        canRedo: _undo!.canRedo,
        focus: focus,
        clearSelection: resetView,
        clearFocus: resetView,
        clearProblem: true,
      ),
    );
    _markDirty();
  }

  // --- палитра ----------------------------------------------------------------------------------------------------

  /// Добавляет цвет и делает его текущим. Возвращает значение сетки нового цвета или `null` при ошибке.
  int? addColor(PatternColor color) {
    if (state.status != EditorStatus.ready) return null;
    final Result<PaletteEdit> edit = _pattern.palette.add(color);
    if (edit case Err<PaletteEdit>()) {
      emit(state.copyWith(problem: EditorProblem.paletteFull));
      return null;
    }
    final PaletteEdit value = edit.valueOrNull!;
    emit(
      state.copyWith(
        pattern: _pattern.copyWith(palette: value.palette),
        activeColor: value.gridValue,
        tool: state.tool == EditorTool.eraser || state.tool == EditorTool.pipette ? EditorTool.brush : state.tool,
        clearProblem: true,
      ),
    );
    _markDirty();
    return value.gridValue;
  }

  /// Меняет название, цвет и позицию каталога цвета палитры; символ остаётся прежним.
  void updateColor(int gridValue, PatternColor color) {
    if (state.status != EditorStatus.ready) return;
    final Result<PaletteEdit> edit = _pattern.palette.replace(gridValue, color);
    if (edit case Success<PaletteEdit>(:final PaletteEdit value)) {
      emit(state.copyWith(pattern: _pattern.copyWith(palette: value.palette), clearProblem: true));
      _markDirty();
    }
  }

  /// Удаляет цвет из палитры вместе с его ячейками; история отмены начинается заново.
  void removeColor(int gridValue) {
    if (state.status != EditorStatus.ready) return;
    final Result<PaletteEdit> edit = _pattern.palette.remove(gridValue);
    if (edit case Success<PaletteEdit>(:final PaletteEdit value)) {
      final Uint16List cells = Uint16List.fromList(_pattern.grid.cells);
      for (int i = 0; i < cells.length; i++) {
        cells[i] = value.reindex.apply(cells[i]);
      }
      final Grid grid = Grid.fromCells(width: _pattern.grid.width, height: _pattern.grid.height, cells: cells);
      _undo = UndoStack(grid);
      final int length = value.palette.length;
      final int active = state.activeColor == gridValue ? (length > 0 ? 1 : 0) : value.reindex.apply(state.activeColor);
      emit(
        state.copyWith(
          pattern: _pattern.copyWith(grid: grid, palette: value.palette),
          activeColor: active,
          canUndo: false,
          canRedo: false,
          clearProblem: true,
        ),
      );
      _markDirty();
    }
  }

  // --- сохранение -------------------------------------------------------------------------------------------------

  void _markDirty() {
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(saveDelay, () => unawaited(flush()));
    if (state.save != EditorSave.pending) emit(state.copyWith(save: EditorSave.pending));
  }

  /// Пишет несохранённые правки сейчас. Вызывается по таймеру, при закрытии экрана и по кнопке «Повторить».
  Future<void> flush() {
    _timer?.cancel();
    return _saving = _saving.then((_) => _writeIfDirty());
  }

  Future<void> _writeIfDirty() async {
    if (!_dirty || state.pattern == null) return;
    _dirty = false;
    final GridPattern snapshot = _pattern;
    final Result<void> saved = await _savePattern(snapshot);
    if (saved case Err<void>()) {
      _dirty = true;
      if (!isClosed) emit(state.copyWith(save: EditorSave.failed, problem: EditorProblem.saveFailed));
      return;
    }
    await _touchProject(_projectId);
    if (!isClosed && !_dirty) emit(state.copyWith(save: EditorSave.saved));
  }

  @override
  Future<void> close() async {
    if (isClosed) return;
    _timer?.cancel();
    // Закрытие экрана не теряет правки: дописываем, что не успело сохраниться.
    if (_dirty) {
      _saving = _saving.then((_) => _writeIfDirty());
    }
    await _saving;
    return super.close();
  }
}
