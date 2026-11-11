import 'dart:ui' show Color;

import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/reading_order.dart';
import 'package:equatable/equatable.dart';

/// Как рисуется клетка вышивки на схеме (бисер этот выбор не использует).
enum StitchStyle {
  /// Клетка закрашена цветом нити.
  color,

  /// Знак палитры на канве, без заливки.
  symbol,

  /// Заливка цветом и знак поверх.
  colorAndSymbol,

  /// Крестики: два стежка, верхний у всех в одну сторону (`\`), как у вышивальщицы.
  crosses,
}

/// Слои вышивки, которые можно скрыть по отдельности.
enum StitchLayerKind { partials, lines, points }

/// Настройки показа схемы. Всё, что не меняет данные схемы.
final class GridViewOptions extends Equatable {
  const GridViewOptions({
    this.showSymbols = false,
    this.showGridLines = true,
    this.boldEvery = 0,
    this.showFinish = true,
    this.realistic = false,
    this.currentRow,
    this.currentCell,
    this.doneRows = const <int>{},
    this.markCurrentRowBeads = true,
    this.order,
    this.pendingCells = const <CellPosition>[],
    this.canvasColor,
    this.stitchStyle,
    this.hiddenLayers = const <StitchLayerKind>{},
    this.highlightColor,
    this.showCenter = false,
    this.doneCells = const <CellPosition>{},
  }) : assert(boldEvery >= 0, 'boldEvery не может быть отрицательным');

  /// Знак палитры на каждой бусине.
  final bool showSymbols;

  /// Тонкие линии между ячейками.
  final bool showGridLines;

  /// Каждая N-я линия жирная; `0` — без жирных (вышивка использует 10).
  final int boldEvery;

  /// Подсказка отделки бусины (блик, металлик, прозрачность).
  final bool showFinish;

  /// Вид «как будет выглядеть»: настоящие бусины или крестики на канве вместо плоской схемы. Символы и линии сетки
  /// в нём не рисуются, отделка бусины рисуется всегда (поверх [showFinish]).
  final bool realistic;

  /// Текущий ряд: двойное кольцо и маркер слева. `null` — нет.
  final int? currentRow;

  /// Текущая бусина в текущем ряду: отдельное двойное кольцо.
  final ({int column, int row})? currentCell;

  /// Пройденные ряды: притушены вуалью.
  final Set<int> doneRows;

  /// Метка на каждой бусине текущего ряда.
  final bool markCurrentRowBeads;

  /// Порядок плетения. Если задан, [currentRow] и [doneRows] — номера рядов плетения (у пейота это столбцы, а у станка
  /// при начале снизу — ряды снизу вверх), иначе — ряды сетки сверху вниз.
  final ReadingOrder? order;

  /// Ещё не выложенные бусины текущего ряда («по бусине»): рисуются пустыми.
  final List<CellPosition> pendingCells;

  /// Цвет канвы вышивки (T46): им закрашены пустые клетки и фон вида «как будет выглядеть». `null` — цвет темы.
  final Color? canvasColor;

  /// Вид клетки вышивки. `null` — по [showSymbols]: знак на заливке или только заливка.
  final StitchStyle? stitchStyle;

  /// Скрытые слои вышивки (неполные крестики, бэкстич, узелки и бусины).
  final Set<StitchLayerKind> hiddenLayers;

  /// Значение сетки (с 1) цвета, который подсвечен: остальные притушены. `null` — подсветки нет.
  final int? highlightColor;

  /// Отметки центра схемы на всех четырёх краях.
  final bool showCenter;

  /// Сделанные клетки вышивки: притушены вуалью.
  final Set<CellPosition> doneCells;

  /// Вид клетки вышивки с учётом [showSymbols].
  StitchStyle get effectiveStitchStyle => stitchStyle ?? (showSymbols ? StitchStyle.colorAndSymbol : StitchStyle.color);

  /// Влияет ли разница на кеш слоя ячеек (остальное рисуется поверх, без пересборки).
  bool sameBaseLayer(GridViewOptions other) =>
      showSymbols == other.showSymbols &&
      showGridLines == other.showGridLines &&
      boldEvery == other.boldEvery &&
      showFinish == other.showFinish &&
      realistic == other.realistic &&
      canvasColor == other.canvasColor &&
      effectiveStitchStyle == other.effectiveStitchStyle &&
      highlightColor == other.highlightColor;

  @override
  List<Object?> get props => <Object?>[
    showSymbols,
    showGridLines,
    boldEvery,
    showFinish,
    realistic,
    currentRow,
    currentCell,
    doneRows,
    markCurrentRowBeads,
    order,
    pendingCells,
    canvasColor,
    stitchStyle,
    hiddenLayers,
    highlightColor,
    showCenter,
    doneCells,
  ];
}
