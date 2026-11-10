import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/reading_order.dart';
import 'package:beading/domain/grid/word_chart.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:equatable/equatable.dart';

enum WeaveStatus { loading, ready, failed }

/// «По ряду» — отмечается ряд целиком; «по бусине» — бусины выкладываются по одной.
enum WeaveMode { byRow, byBead }

/// Экран плетения по своей схеме.
///
/// Номера рядов — ряды плетения ([ReadingOrder]) с нуля. [laid] — сколько бусин текущего ряда уже выложено; у ряда
/// без пустых ячеек это число от `0` до `beadCount - 1`: когда выложена последняя, ряд завершается.
class WeaveState extends Equatable {
  const WeaveState({
    this.status = WeaveStatus.loading,
    this.projectName = '',
    this.pattern,
    this.order,
    this.mode = WeaveMode.byRow,
    this.showSymbols = false,
    this.row = 0,
    this.laid = 0,
    this.completedRows = const <int>{},
    this.runs = const <WordRun>[],
    this.beadCells = const <CellPosition>[],
    this.cells = const <CellPosition>[],
    this.direction = RowDirection.right,
    this.toastRow,
    this.offerFinish = false,
    this.projectDone = false,
    this.saveFailed = false,
    this.completions = 0,
  });

  final WeaveStatus status;
  final String projectName;
  final GridPattern? pattern;
  final ReadingOrder? order;
  final WeaveMode mode;
  final bool showSymbols;

  /// Текущий ряд плетения.
  final int row;

  /// Выложено бусин в текущем ряду.
  final int laid;

  final Set<int> completedRows;

  /// Word chart текущего ряда, в порядке плетения.
  final List<WordRun> runs;

  /// Бусины текущего ряда (без пустых ячеек) в порядке плетения.
  final List<CellPosition> beadCells;

  /// Все ячейки текущего ряда в порядке плетения.
  final List<CellPosition> cells;

  final RowDirection direction;

  /// Ряд, о завершении которого показан тост «Отменить»; `null` — тоста нет.
  final int? toastRow;

  /// Последний ряд закончен: предложить отметить проект «готово».
  final bool offerFinish;

  final bool projectDone;
  final bool saveFailed;

  /// Сколько раз завершали ряд на этом экране: по росту числа экран отзывается вибрацией.
  final int completions;

  bool get isReady => status == WeaveStatus.ready;

  int get rowCount => order?.rowCount ?? 0;

  int get beadCount => beadCells.length;

  /// Номер ряда для показа, с единицы.
  int get rowNumber => row + 1;

  /// Все ряды схемы отмечены.
  bool get allDone => rowCount > 0 && completedRows.length >= rowCount;

  bool get isLastRow => row == rowCount - 1;

  bool get canGoBack => laid > 0 || completedRows.contains(row) || row > 0;

  /// Доля отмеченных рядов, от нуля до единицы.
  double get progress => rowCount == 0 ? 0 : completedRows.length / rowCount;

  /// Текущая бусина «по бусине» — следующая, которую нужно выложить; `null`, если выкладывать нечего.
  CellPosition? get nextBead => mode == WeaveMode.byBead && laid < beadCells.length ? beadCells[laid] : null;

  /// Ещё не выложенные бусины текущего ряда («по бусине»).
  List<CellPosition> get pendingBeads => mode == WeaveMode.byBead && !allDone
      ? beadCells.sublist(laid.clamp(0, beadCells.length))
      : const <CellPosition>[];

  WeaveState copyWith({
    WeaveStatus? status,
    String? projectName,
    GridPattern? pattern,
    ReadingOrder? order,
    WeaveMode? mode,
    bool? showSymbols,
    int? row,
    int? laid,
    Set<int>? completedRows,
    List<WordRun>? runs,
    List<CellPosition>? beadCells,
    List<CellPosition>? cells,
    RowDirection? direction,
    int? toastRow,
    bool clearToast = false,
    bool? offerFinish,
    bool? projectDone,
    bool? saveFailed,
    int? completions,
  }) => WeaveState(
    status: status ?? this.status,
    projectName: projectName ?? this.projectName,
    pattern: pattern ?? this.pattern,
    order: order ?? this.order,
    mode: mode ?? this.mode,
    showSymbols: showSymbols ?? this.showSymbols,
    row: row ?? this.row,
    laid: laid ?? this.laid,
    completedRows: completedRows ?? this.completedRows,
    runs: runs ?? this.runs,
    beadCells: beadCells ?? this.beadCells,
    cells: cells ?? this.cells,
    direction: direction ?? this.direction,
    toastRow: clearToast ? null : (toastRow ?? this.toastRow),
    offerFinish: offerFinish ?? this.offerFinish,
    projectDone: projectDone ?? this.projectDone,
    saveFailed: saveFailed ?? this.saveFailed,
    completions: completions ?? this.completions,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    projectName,
    pattern,
    order,
    mode,
    showSymbols,
    row,
    laid,
    completedRows.toList()..sort(),
    runs,
    beadCells,
    cells,
    direction,
    toastRow,
    offerFinish,
    projectDone,
    saveFailed,
    completions,
  ];
}
