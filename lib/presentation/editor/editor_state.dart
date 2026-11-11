import 'package:beading/domain/editor/cell_rect.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:equatable/equatable.dart';

/// Инструмент редактора.
enum EditorTool {
  brush,
  eraser,
  fill,
  pipette,
  replaceColor,
  selection,

  /// Полукрестик: диагональ выбирается по месту касания в клетке (только вышивка).
  halfStitch,

  /// Четверть крестика у ближайшего угла клетки.
  quarterStitch,

  /// ¾ крестика: диагональ и четверть у ближайшего угла.
  threeQuarterStitch,

  /// Петит: маленький крестик в четверти клетки.
  petit,

  /// Бэкстич: касание узлов ставит ломаную, протяжка — один отрезок.
  backstitch,

  /// Французский узелок в ближайшем узле.
  knot,

  /// Бусина в ближайшем узле: позиция каталога бисера выбирается отдельно.
  bead,
  ;

  /// Инструменты, которые работают в точках внутри клетки (узлы и углы), а не по целым клеткам.
  bool get isStitchPoint =>
      this == halfStitch ||
      this == quarterStitch ||
      this == threeQuarterStitch ||
      this == petit ||
      this == backstitch ||
      this == knot ||
      this == bead;
}

/// Где находится правка относительно диска.
enum EditorSave {
  /// Всё записано.
  saved,

  /// Есть правки, запись ждёт паузы (debounce) или идёт.
  pending,

  /// Последняя запись не удалась; правки остаются на экране и записываются повторно.
  failed,
}

enum EditorStatus { loading, ready, loadFailed }

/// Что пошло не так, в терминах для текста на экране.
enum EditorProblem { saveFailed, noColor, noBead, paletteFull, limitReached, lastRowOrColumn }

class EditorState extends Equatable {
  const EditorState({
    this.status = EditorStatus.loading,
    this.projectName = '',
    this.pattern,
    this.layers,
    this.lineAnchor,
    this.activeBead,
    this.beadColors = const <CatalogRef, Rgb>{},
    this.tool = EditorTool.brush,
    this.activeColor = 0,
    this.selection,
    this.focus,
    this.canUndo = false,
    this.canRedo = false,
    this.save = EditorSave.saved,
    this.showSymbols = false,
    this.problem,
  });

  final EditorStatus status;
  final String projectName;

  /// Редактируемая схема (после загрузки). Сетка меняется при каждом мазке.
  final GridPattern? pattern;

  /// Слои вышивки (неполные крестики, бэкстич, узелки); у бисерной схемы `null`.
  final StitchLayers? layers;

  /// Начало ломаной бэкстича: следующее касание узла проведёт отрезок от него.
  final LatticeNode? lineAnchor;

  /// Бусина, которую ставит инструмент «Бусина»; `null` — ещё не выбрана.
  final CatalogRef? activeBead;

  /// Цвета бусин слоёв (каталог бисера схема не хранит): известны для выбранных и найденных в каталоге бусин.
  final Map<CatalogRef, Rgb> beadColors;
  final EditorTool tool;

  /// Значение сетки текущего цвета: `0` — цвета нет (палитра пуста), `n` — `palette[n - 1]`.
  final int activeColor;
  final CellRect? selection;

  /// Последняя ячейка, которой коснулись: от неё работают вставка и удаление рядов и столбцов.
  final CellPosition? focus;
  final bool canUndo;
  final bool canRedo;
  final EditorSave save;
  final bool showSymbols;
  final EditorProblem? problem;

  /// Редактируется схема вышивки: у неё есть слои и свои инструменты.
  bool get isStitch => layers != null;

  EditorState copyWith({
    EditorStatus? status,
    String? projectName,
    GridPattern? pattern,
    StitchLayers? layers,
    LatticeNode? lineAnchor,
    bool clearLineAnchor = false,
    CatalogRef? activeBead,
    Map<CatalogRef, Rgb>? beadColors,
    EditorTool? tool,
    int? activeColor,
    CellRect? selection,
    bool clearSelection = false,
    CellPosition? focus,
    bool clearFocus = false,
    bool? canUndo,
    bool? canRedo,
    EditorSave? save,
    bool? showSymbols,
    EditorProblem? problem,
    bool clearProblem = false,
  }) => EditorState(
    status: status ?? this.status,
    projectName: projectName ?? this.projectName,
    pattern: pattern ?? this.pattern,
    layers: layers ?? this.layers,
    lineAnchor: clearLineAnchor ? null : (lineAnchor ?? this.lineAnchor),
    activeBead: activeBead ?? this.activeBead,
    beadColors: beadColors ?? this.beadColors,
    tool: tool ?? this.tool,
    activeColor: activeColor ?? this.activeColor,
    selection: clearSelection ? null : (selection ?? this.selection),
    focus: clearFocus ? null : (focus ?? this.focus),
    canUndo: canUndo ?? this.canUndo,
    canRedo: canRedo ?? this.canRedo,
    save: save ?? this.save,
    showSymbols: showSymbols ?? this.showSymbols,
    problem: clearProblem ? null : (problem ?? this.problem),
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    projectName,
    pattern,
    layers,
    lineAnchor,
    activeBead,
    beadColors,
    tool,
    activeColor,
    selection,
    focus,
    canUndo,
    canRedo,
    save,
    showSymbols,
    problem,
  ];
}
