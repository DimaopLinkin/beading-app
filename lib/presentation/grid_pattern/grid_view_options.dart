import 'package:equatable/equatable.dart';

/// Настройки показа схемы. Всё, что не меняет данные схемы.
final class GridViewOptions extends Equatable {
  const GridViewOptions({
    this.showSymbols = false,
    this.showGridLines = true,
    this.boldEvery = 0,
    this.showFinish = true,
    this.currentRow,
    this.currentCell,
    this.doneRows = const <int>{},
    this.markCurrentRowBeads = true,
  }) : assert(boldEvery >= 0, 'boldEvery не может быть отрицательным');

  /// Знак палитры на каждой бусине.
  final bool showSymbols;

  /// Тонкие линии между ячейками.
  final bool showGridLines;

  /// Каждая N-я линия жирная; `0` — без жирных (вышивка использует 10).
  final int boldEvery;

  /// Подсказка отделки бусины (блик, металлик, прозрачность).
  final bool showFinish;

  /// Текущий ряд: двойное кольцо и маркер слева. `null` — нет.
  final int? currentRow;

  /// Текущая бусина в текущем ряду: отдельное двойное кольцо.
  final ({int column, int row})? currentCell;

  /// Пройденные ряды: притушены вуалью.
  final Set<int> doneRows;

  /// Метка на каждой бусине текущего ряда.
  final bool markCurrentRowBeads;

  /// Влияет ли разница на кеш слоя ячеек (остальное рисуется поверх, без пересборки).
  bool sameBaseLayer(GridViewOptions other) =>
      showSymbols == other.showSymbols &&
      showGridLines == other.showGridLines &&
      boldEvery == other.boldEvery &&
      showFinish == other.showFinish;

  @override
  List<Object?> get props => <Object?>[
    showSymbols,
    showGridLines,
    boldEvery,
    showFinish,
    currentRow,
    currentCell,
    doneRows,
    markCurrentRowBeads,
  ];
}
