import 'package:beading/domain/editor/cell_rect.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/stitch_counters.dart';
import 'package:beading/domain/printing/print_options.dart';
import 'package:equatable/equatable.dart';

enum StitchStatus { loading, ready, failed }

/// Чем отмечают: касанием одной клетки, мазком или областью.
enum StitchTool { tap, stroke, area }

/// Экран вышивания: схема, отметки «сделано», счётчики по цветам и по блокам 10×10.
class StitchState extends Equatable {
  const StitchState({
    this.status = StitchStatus.loading,
    this.projectName = '',
    this.pattern,
    this.progress = const CellProgress.none(),
    this.tool = StitchTool.tap,
    this.showSymbols = false,
    this.printOptions = const PrintOptions(),
    this.showBlocks = true,
    this.highlight,
    this.parked,
    this.byColor = const <ColorCount>[],
    this.blocks = const <BlockCount>[],
    this.total = 0,
    this.done = 0,
    this.areaPreview,
    this.offerFinish = false,
    this.projectDone = false,
    this.saveFailed = false,
    this.marks = 0,
    this.canUndo = false,
    this.undoNotice,
  });

  final StitchStatus status;
  final String projectName;
  final GridPattern? pattern;

  /// Отметки «сделано».
  final CellProgress progress;
  final StitchTool tool;
  final bool showSymbols;

  /// Настройки стойки для игл: номер цвета в списке такой же, как в легенде PDF (T82).
  final PrintOptions printOptions;

  /// Показывать процент по блокам 10×10.
  final bool showBlocks;

  /// Значение сетки (с 1) подсвеченного цвета; `null` — подсветки нет.
  final int? highlight;

  /// Клетка, на которой остановились («парковка»); `null` — не выбрана.
  final CellPosition? parked;

  /// Сколько клеток каждого цвета и сколько сделано; по порядку палитры.
  final List<ColorCount> byColor;

  /// Блоки с хотя бы одной клеткой цвета.
  final List<BlockCount> blocks;

  /// Всего клеток с цветом и сколько сделано.
  final int total;
  final int done;

  /// Рамка области, пока её тянут.
  final CellRect? areaPreview;

  /// Все клетки сделаны: предложить отметить проект готовым.
  final bool offerFinish;
  final bool projectDone;
  final bool saveFailed;

  /// Сколько раз отметка менялась на этом экране: по росту числа экран отзывается вибрацией.
  final int marks;

  /// Есть что откатывать.
  final bool canUndo;

  /// Тост после мазка, области или цвета целиком: сколько клеток отмечено (`done`) или снято. `null` — тоста нет.
  final ({int count, bool done})? undoNotice;

  bool get isReady => status == StitchStatus.ready;

  int get remaining => total - done;

  /// Доля сделанного, от нуля до единицы.
  double get fraction => total == 0 ? 0 : done / total;

  bool get allDone => total > 0 && done >= total;

  StitchState copyWith({
    StitchStatus? status,
    String? projectName,
    GridPattern? pattern,
    CellProgress? progress,
    StitchTool? tool,
    bool? showSymbols,
    PrintOptions? printOptions,
    bool? showBlocks,
    int? highlight,
    bool clearHighlight = false,
    CellPosition? parked,
    bool clearParked = false,
    List<ColorCount>? byColor,
    List<BlockCount>? blocks,
    int? total,
    int? done,
    CellRect? areaPreview,
    bool clearAreaPreview = false,
    bool? offerFinish,
    bool? projectDone,
    bool? saveFailed,
    int? marks,
    bool? canUndo,
    ({int count, bool done})? undoNotice,
    bool clearUndoNotice = false,
  }) => StitchState(
    status: status ?? this.status,
    projectName: projectName ?? this.projectName,
    pattern: pattern ?? this.pattern,
    progress: progress ?? this.progress,
    tool: tool ?? this.tool,
    showSymbols: showSymbols ?? this.showSymbols,
    printOptions: printOptions ?? this.printOptions,
    showBlocks: showBlocks ?? this.showBlocks,
    highlight: clearHighlight ? null : (highlight ?? this.highlight),
    parked: clearParked ? null : (parked ?? this.parked),
    byColor: byColor ?? this.byColor,
    blocks: blocks ?? this.blocks,
    total: total ?? this.total,
    done: done ?? this.done,
    areaPreview: clearAreaPreview ? null : (areaPreview ?? this.areaPreview),
    offerFinish: offerFinish ?? this.offerFinish,
    projectDone: projectDone ?? this.projectDone,
    saveFailed: saveFailed ?? this.saveFailed,
    marks: marks ?? this.marks,
    canUndo: canUndo ?? this.canUndo,
    undoNotice: clearUndoNotice ? null : (undoNotice ?? this.undoNotice),
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    projectName,
    pattern,
    progress,
    tool,
    showSymbols,
    printOptions,
    showBlocks,
    highlight,
    parked,
    byColor,
    blocks,
    total,
    done,
    areaPreview,
    offerFinish,
    projectDone,
    saveFailed,
    marks,
    canUndo,
    undoNotice,
  ];
}
