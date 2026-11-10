import 'package:beading/domain/editor/cell_rect.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:equatable/equatable.dart';

/// Инструмент редактора.
enum EditorTool { brush, eraser, fill, pipette, replaceColor, selection }

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
enum EditorProblem { saveFailed, noColor, paletteFull, limitReached, lastRowOrColumn }

class EditorState extends Equatable {
  const EditorState({
    this.status = EditorStatus.loading,
    this.projectName = '',
    this.pattern,
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

  EditorState copyWith({
    EditorStatus? status,
    String? projectName,
    GridPattern? pattern,
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
