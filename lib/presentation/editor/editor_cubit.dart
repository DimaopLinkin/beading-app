import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/editor/cell_line.dart';
import 'package:beading/domain/editor/cell_rect.dart';
import 'package:beading/domain/editor/editor_commands.dart';
import 'package:beading/domain/editor/editor_snapshot.dart';
import 'package:beading/domain/editor/undo_stack.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/use_cases/save_grid_pattern.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:beading/domain/stitch/point_stitch.dart';
import 'package:beading/domain/stitch/stitch_layer_commands.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_layers_codec.dart';
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
    CatalogRepository? catalog,
    this.saveDelay = const Duration(milliseconds: 400),
  }) : _projectId = projectId,
       _projects = projects,
       _patterns = patterns,
       _savePattern = savePattern,
       _touchProject = touchProject,
       _catalog = catalog,
       super(const EditorState());

  final Duration saveDelay;

  final String _projectId;
  final ProjectRepository _projects;
  final GridPatternRepository _patterns;
  final SaveGridPattern _savePattern;
  final TouchProject _touchProject;
  final CatalogRepository? _catalog;

  UndoStack<EditorSnapshot>? _undo;
  Timer? _timer;
  Future<void> _saving = Future<void>.value();
  bool _dirty = false;
  bool _stroking = false;
  CellPosition? _lastStrokeCell;

  GridPattern get _pattern => state.pattern!;

  bool get _ready => !isClosed && state.status == EditorStatus.ready;

  Future<void> load() async {
    final Result<Project> project = await _projects.get(_projectId);
    final Result<GridPattern> pattern = await _patterns.getByProject(_projectId);
    if (isClosed) return;
    if (project case Success<Project>(:final Project value) when pattern is Success<GridPattern>) {
      final GridPattern loaded = pattern.valueOrNull!;
      final StitchLayers? layers = value.craft == Craft.crossStitch ? _layersOf(loaded) : null;
      _undo = UndoStack<EditorSnapshot>(EditorSnapshot(grid: loaded.grid, layers: layers));
      emit(
        state.copyWith(
          status: EditorStatus.ready,
          projectName: value.name,
          pattern: loaded,
          layers: layers,
          activeColor: loaded.palette.length > 0 ? 1 : 0,
        ),
      );
      unawaited(_resolveBeadColors(layers));
      return;
    }
    emit(state.copyWith(status: EditorStatus.loadFailed));
  }

  /// Слои схемы вышивки: сохранённые или пустые; нечитаемые слои тоже заменяются пустыми, чтобы схему можно было
  /// открыть (крестики при этом целы).
  static StitchLayers _layersOf(GridPattern pattern) {
    final GridLayersBlob? blob = pattern.layers;
    final StitchLayers empty = StitchLayers.empty(columns: pattern.grid.width, rows: pattern.grid.height);
    if (blob == null) return empty;
    final StitchLayers? decoded = StitchLayersCodec.fromBlob(blob).valueOrNull;
    return decoded != null && decoded.columns == pattern.grid.width && decoded.rows == pattern.grid.height
        ? decoded
        : empty;
  }

  EditorSnapshot get _snapshot => _undo!.current;

  /// Находит в каталоге цвета бусин слоёв: схема хранит только позицию, а на экране бусина должна быть своего цвета.
  Future<void> _resolveBeadColors(StitchLayers? layers) async {
    final CatalogRepository? catalog = _catalog;
    if (catalog == null || layers == null) return;
    final Set<CatalogRef> refs = <CatalogRef>{
      for (final PointStitch p in layers.points)
        if (p.bead != null) p.bead!,
    };
    final Map<CatalogRef, Rgb> found = <CatalogRef, Rgb>{};
    for (final CatalogRef ref in refs) {
      final CatalogColor? color = (await catalog.find(ref.brand, ref.code)).valueOrNull;
      if (color != null) found[ref] = color.rgb;
    }
    if (isClosed || found.isEmpty) return;
    emit(state.copyWith(beadColors: <CatalogRef, Rgb>{...state.beadColors, ...found}));
  }

  /// Выбирает бусину для инструмента «Бусина»; [rgb] — её цвет для экрана.
  void selectBead(CatalogRef ref, Rgb rgb) {
    if (!_ready || !state.isStitch) return;
    emit(
      state.copyWith(
        activeBead: ref,
        beadColors: <CatalogRef, Rgb>{...state.beadColors, ref: rgb},
        tool: EditorTool.bead,
        clearLineAnchor: true,
        clearProblem: true,
      ),
    );
  }

  // --- инструменты ------------------------------------------------------------------------------------------------

  void selectTool(EditorTool tool) {
    if (state.status != EditorStatus.ready) return;
    if (tool.isStitchPoint && !state.isStitch) return;
    emit(
      state.copyWith(
        tool: tool,
        clearProblem: true,
        clearSelection: tool != EditorTool.selection,
        clearLineAnchor: true,
      ),
    );
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
      case EditorTool.halfStitch:
      case EditorTool.quarterStitch:
      case EditorTool.threeQuarterStitch:
      case EditorTool.petit:
      case EditorTool.backstitch:
      case EditorTool.knot:
      case EditorTool.bead:
        // Эти инструменты работают в точках внутри клетки: касание придёт в [tapPoint].
        break;
    }
  }

  /// Начало мазка кистью или ластиком: до [endStroke] все ячейки — один шаг отмены.
  void beginStroke() {
    if (state.status != EditorStatus.ready || _stroking) return;
    if (state.tool == EditorTool.selection || state.tool.isStitchPoint) return;
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
    StitchLayers? layers = state.layers;
    if (layers != null && state.tool == EditorTool.eraser) {
      for (final CellPosition c in cells) {
        if (state.selection == null || state.selection!.contains(c)) layers = StitchLayerCommands.clearCell(layers!, c);
      }
    }
    _apply(
      _snapshot.copyWith(grid: next, layers: layers),
      focus: cell,
    );
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

  // --- вышивка: стежки внутри клетки -------------------------------------------------------------------------------

  /// Касание точки схемы: [point] — в клетках от левого верхнего угла (дробная часть — место в клетке). Действие
  /// зависит от инструмента: неполный крестик, узел бэкстича, узелок или ластик для линий и узелков.
  void tapPoint(Offset point) {
    final StitchLayers? layers = state.layers;
    if (!_ready || layers == null) return;
    final int column = point.dx.floor();
    final int row = point.dy.floor();
    final bool inside = column >= 0 && row >= 0 && column < layers.columns && row < layers.rows;
    // Узлы лежат и на внешней границе схемы: касание чуть за краем кладёт их на край; клеточным инструментам нужна клетка.
    final bool nodeTool =
        state.tool == EditorTool.backstitch || state.tool == EditorTool.knot || state.tool == EditorTool.bead;
    if (!inside && !nodeTool) return;
    if (inside) emit(state.copyWith(focus: CellPosition(column, row)));
    switch (state.tool) {
      case EditorTool.halfStitch:
      case EditorTool.quarterStitch:
      case EditorTool.threeQuarterStitch:
      case EditorTool.petit:
        _togglePartial(layers, point, column, row);
      case EditorTool.backstitch:
        _backstitchNode(layers, _nodeNear(layers, point));
      case EditorTool.knot:
        _toggleKnot(layers, _nodeNear(layers, point));
      case EditorTool.bead:
        _toggleBead(layers, _nodeNear(layers, point));
      case EditorTool.eraser:
        _eraseAt(layers, point, CellPosition(column, row));
      case EditorTool.brush:
      case EditorTool.fill:
      case EditorTool.pipette:
      case EditorTool.replaceColor:
      case EditorTool.selection:
        break;
    }
  }

  /// Протяжка бэкстича от [from] до [to] (в клетках): один отрезок между ближайшими узлами.
  void dragLine(Offset from, Offset to) {
    final StitchLayers? layers = state.layers;
    if (!_ready || layers == null || state.tool != EditorTool.backstitch) return;
    if (state.activeColor == 0) {
      emit(state.copyWith(problem: EditorProblem.noColor));
      return;
    }
    final LatticeNode a = _nodeNear(layers, from);
    final LatticeNode b = _nodeNear(layers, to);
    if (a == b) {
      _backstitchNode(layers, a);
      return;
    }
    _apply(
      _snapshot.copyWith(
        layers: StitchLayerCommands.addLine(
          layers,
          LineStitch(a: a, b: b, kind: LineKind.backstitch, color: state.activeColor),
        ),
      ),
    );
    emit(state.copyWith(lineAnchor: b, clearProblem: true));
  }

  LatticeNode _nodeNear(StitchLayers layers, Offset point) => LatticeNode(
    (point.dx * 2).round().clamp(0, layers.columns * 2),
    (point.dy * 2).round().clamp(0, layers.rows * 2),
  );

  void _togglePartial(StitchLayers layers, Offset point, int column, int row) {
    if (state.activeColor == 0) {
      emit(state.copyWith(problem: EditorProblem.noColor));
      return;
    }
    final double fx = point.dx - column;
    final double fy = point.dy - row;
    final StitchOrientation corner = switch ((fx < 0.5, fy < 0.5)) {
      (true, true) => StitchOrientation.topLeft,
      (false, true) => StitchOrientation.topRight,
      (true, false) => StitchOrientation.bottomLeft,
      (false, false) => StitchOrientation.bottomRight,
    };
    final PartialKind kind = switch (state.tool) {
      EditorTool.halfStitch => PartialKind.half,
      EditorTool.quarterStitch => PartialKind.quarter,
      EditorTool.threeQuarterStitch => PartialKind.threeQuarter,
      _ => PartialKind.petit,
    };
    // Полукрестик: ближайшая к касанию диагональ клетки.
    final StitchOrientation orientation = kind == PartialKind.half
        ? ((fx + fy - 1).abs() < (fx - fy).abs() ? StitchOrientation.slash : StitchOrientation.backslash)
        : corner;
    final PartialStitch stitch = PartialStitch(
      column: column,
      row: row,
      kind: kind,
      orientation: orientation,
      color: state.activeColor,
    );
    final bool same = layers.partials.any((p) => p == stitch);
    _apply(
      _snapshot.copyWith(
        layers: same
            ? StitchLayerCommands.removePartial(layers, stitch.cell, kind, orientation)
            : StitchLayerCommands.addPartial(layers, stitch),
      ),
    );
  }

  /// Касание узла бэкстича: первое запоминает начало, следующие тянут ломаную; повторное касание того же узла
  /// заканчивает ломаную.
  void _backstitchNode(StitchLayers layers, LatticeNode node) {
    if (state.activeColor == 0) {
      emit(state.copyWith(problem: EditorProblem.noColor));
      return;
    }
    final LatticeNode? anchor = state.lineAnchor;
    if (anchor == null) {
      emit(state.copyWith(lineAnchor: node, clearProblem: true));
    } else if (anchor == node) {
      emit(state.copyWith(clearLineAnchor: true));
    } else {
      _apply(
        _snapshot.copyWith(
          layers: StitchLayerCommands.addLine(
            layers,
            LineStitch(a: anchor, b: node, kind: LineKind.backstitch, color: state.activeColor),
          ),
        ),
      );
      emit(state.copyWith(lineAnchor: node, clearProblem: true));
    }
  }

  void _toggleKnot(StitchLayers layers, LatticeNode node) {
    if (state.activeColor == 0) {
      emit(state.copyWith(problem: EditorProblem.noColor));
      return;
    }
    final bool same = layers.points.any(
      (p) => p.node == node && p.kind == PointKind.frenchKnot && p.color == state.activeColor,
    );
    _apply(
      _snapshot.copyWith(
        layers: same
            ? StitchLayerCommands.removePoint(layers, node)
            : StitchLayerCommands.addPoint(
                layers,
                PointStitch.knot(node: node, kind: PointKind.frenchKnot, color: state.activeColor),
              ),
      ),
    );
  }

  void _toggleBead(StitchLayers layers, LatticeNode node) {
    final CatalogRef? bead = state.activeBead;
    if (bead == null) {
      emit(state.copyWith(problem: EditorProblem.noBead));
      return;
    }
    final bool same = layers.points.any((p) => p.node == node && p.bead == bead);
    _apply(
      _snapshot.copyWith(
        layers: same
            ? StitchLayerCommands.removePoint(layers, node)
            : StitchLayerCommands.addPoint(layers, PointStitch.bead(node: node, bead: bead)),
      ),
    );
  }

  /// Ластик одним касанием: линия или узелок рядом; если их нет — вся клетка (крестик и неполные стежки).
  void _eraseAt(StitchLayers layers, Offset point, CellPosition cell) {
    final StitchLayers near = StitchLayerCommands.eraseNear(layers, point.dx, point.dy);
    if (!identical(near, layers)) {
      _apply(_snapshot.copyWith(layers: near));
      return;
    }
    _apply(
      _snapshot.copyWith(
        grid: EditorCommands.erase(_pattern.grid, <CellPosition>[cell], within: state.selection),
        layers: StitchLayerCommands.clearCell(layers, cell),
      ),
      focus: cell,
    );
  }

  // --- выделение и преобразования ---------------------------------------------------------------------------------

  void selectRect(CellPosition a, CellPosition b) {
    if (state.status != EditorStatus.ready) return;
    emit(state.copyWith(selection: CellRect.fromCorners(a, b), focus: b));
  }

  void clearSelection() => emit(state.copyWith(clearSelection: true));

  /// Зеркало по горизонтали для выделения (или всей схемы). Для мозаики и кирпичика зеркалятся индексы ячеек, а не
  /// физическая раскладка: экран говорит об этом.
  ///
  /// У вышивки зеркалится вся схема вместе со слоями: выделение не учитывается.
  void mirrorHorizontal() {
    if (!_ready) return;
    final StitchLayers? layers = state.layers;
    if (layers == null) {
      _applyGrid(EditorCommands.mirrorHorizontal(_pattern.grid, within: state.selection));
    } else {
      _apply(
        EditorSnapshot(
          grid: EditorCommands.mirrorHorizontal(_pattern.grid),
          layers: StitchLayerCommands.mirrorHorizontal(layers),
        ),
      );
    }
  }

  void mirrorVertical() {
    if (!_ready) return;
    final StitchLayers? layers = state.layers;
    if (layers == null) {
      _applyGrid(EditorCommands.mirrorVertical(_pattern.grid, within: state.selection));
    } else {
      _apply(
        EditorSnapshot(
          grid: EditorCommands.mirrorVertical(_pattern.grid),
          layers: StitchLayerCommands.mirrorVertical(layers),
        ),
      );
    }
  }

  void insertRow(int at) {
    if (_ready) _applyResult(EditorCommands.insertRow(_pattern.grid, at), (l) => StitchLayerCommands.insertRow(l, at));
  }

  void deleteRow(int at) {
    if (_ready) _applyResult(EditorCommands.deleteRow(_pattern.grid, at), (l) => StitchLayerCommands.deleteRow(l, at));
  }

  void insertColumn(int at) {
    if (_ready) {
      _applyResult(EditorCommands.insertColumn(_pattern.grid, at), (l) => StitchLayerCommands.insertColumn(l, at));
    }
  }

  void deleteColumn(int at) {
    if (_ready) {
      _applyResult(EditorCommands.deleteColumn(_pattern.grid, at), (l) => StitchLayerCommands.deleteColumn(l, at));
    }
  }

  void _applyResult(Result<Grid> result, StitchLayers Function(StitchLayers layers) onLayers) {
    switch (result) {
      case Success<Grid>(:final Grid value):
        // Форма меняется: выделение и фокус больше не указывают на те же ячейки.
        final StitchLayers? layers = state.layers;
        _apply(
          EditorSnapshot(grid: value, layers: layers == null ? null : onLayers(layers)),
          resetView: true,
        );
      case Err<Grid>():
        final bool atLimit = result.failureOrNull!.message.contains('максимум');
        emit(state.copyWith(problem: atLimit ? EditorProblem.limitReached : EditorProblem.lastRowOrColumn));
    }
  }

  // --- отмена -----------------------------------------------------------------------------------------------------

  void undo() {
    if (!_ready) return;
    final EditorSnapshot? snapshot = _undo!.undo();
    if (snapshot != null) _afterHistory(snapshot);
  }

  void redo() {
    if (!_ready) return;
    final EditorSnapshot? snapshot = _undo!.redo();
    if (snapshot != null) _afterHistory(snapshot);
  }

  void _afterHistory(EditorSnapshot snapshot) {
    _stroking = false;
    final Grid grid = snapshot.grid;
    final bool shapeChanged = grid.width != _pattern.grid.width || grid.height != _pattern.grid.height;
    emit(
      state.copyWith(
        pattern: _pattern.copyWith(grid: grid),
        layers: snapshot.layers,
        canUndo: _undo!.canUndo,
        canRedo: _undo!.canRedo,
        clearSelection: shapeChanged,
        clearFocus: shapeChanged,
        clearLineAnchor: true,
        clearProblem: true,
      ),
    );
    _markDirty();
  }

  void _applyGrid(Grid next, {CellPosition? focus, bool resetView = false}) => _apply(
    _snapshot.copyWith(grid: next),
    focus: focus,
    resetView: resetView,
  );

  void _apply(EditorSnapshot next, {CellPosition? focus, bool resetView = false}) {
    if (next == _snapshot) return;
    _undo!.apply(next);
    emit(
      state.copyWith(
        pattern: _pattern.copyWith(grid: next.grid),
        layers: next.layers,
        canUndo: _undo!.canUndo,
        canRedo: _undo!.canRedo,
        focus: focus,
        clearSelection: resetView,
        clearFocus: resetView,
        clearLineAnchor: resetView,
        clearProblem: true,
      ),
    );
    _markDirty();
  }

  // --- палитра ----------------------------------------------------------------------------------------------------

  /// Добавляет цвет и делает его текущим. Возвращает значение сетки нового цвета или `null` при ошибке.
  int? addColor(PatternColor color) {
    if (!_ready) return null;
    endStroke();
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
    if (!_ready) return;
    endStroke();
    final Result<PaletteEdit> edit = _pattern.palette.replace(gridValue, color);
    if (edit case Success<PaletteEdit>(:final PaletteEdit value)) {
      emit(state.copyWith(pattern: _pattern.copyWith(palette: value.palette), clearProblem: true));
      _markDirty();
    }
  }

  /// Удаляет цвет из палитры вместе с его ячейками; история отмены начинается заново.
  void removeColor(int gridValue) {
    if (!_ready) return;
    endStroke();
    final Result<PaletteEdit> edit = _pattern.palette.remove(gridValue);
    if (edit case Success<PaletteEdit>(:final PaletteEdit value)) {
      final Uint16List cells = Uint16List.fromList(_pattern.grid.cells);
      for (int i = 0; i < cells.length; i++) {
        cells[i] = value.reindex.apply(cells[i]);
      }
      final Grid grid = Grid.fromCells(width: _pattern.grid.width, height: _pattern.grid.height, cells: cells);
      final StitchLayers? layers = state.layers == null
          ? null
          : StitchLayerCommands.reindexColors(state.layers!, value.reindex);
      _undo = UndoStack<EditorSnapshot>(EditorSnapshot(grid: grid, layers: layers));
      final int length = value.palette.length;
      final int active = state.activeColor == gridValue ? (length > 0 ? 1 : 0) : value.reindex.apply(state.activeColor);
      emit(
        state.copyWith(
          pattern: _pattern.copyWith(grid: grid, palette: value.palette),
          layers: layers,
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
    final StitchLayers? layers = state.layers;
    final GridPattern snapshot = layers == null
        ? _pattern
        : _pattern.copyWith(layers: StitchLayersCodec.toBlob(layers));
    Result<void> saved;
    try {
      saved = await _savePattern(snapshot);
      if (saved is Success<void>) {
        // Подъём проекта в библиотеке не должен ронять сохранение: ошибка тут не страшна.
        await _touchProject(_projectId);
      }
    } on Object {
      saved = const Err<void>(UnexpectedFailure('сохранение схемы'));
    }
    if (saved case Err<void>()) {
      _dirty = true;
      if (!isClosed) emit(state.copyWith(save: EditorSave.failed, problem: EditorProblem.saveFailed));
      return;
    }
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
