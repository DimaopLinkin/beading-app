import 'package:beading/domain/printing/print_options.dart';
import 'package:equatable/equatable.dart';

/// Прямоугольник клеток схемы на одной странице: `[column, column + columns) × [row, row + rows)`.
final class PrintTile extends Equatable {
  const PrintTile({required this.column, required this.row, required this.columns, required this.rows});

  final int column;
  final int row;
  final int columns;
  final int rows;

  int get columnEnd => column + columns;
  int get rowEnd => row + rows;

  @override
  List<Object?> get props => <Object?>[column, row, columns, rows];
}

/// Раскладка листов схемы в масштабе «10 крестиков = 3 см»: клетка 3 мм при любом формате.
///
/// Считается в пикселях растра ([PrintPaper.pixelsPerMm]). Страницы нарезаны так, что число клеток кратно десяти:
/// границы совпадают с подписями, а номера на краях сходятся с соседней страницей. Легенда печатается отдельно на
/// листах A4 ([LegendLayout]).
final class PrintLayout {
  PrintLayout(this.paper)
    : pixelsPerMm = paper.pixelsPerMm,
      cellPx = 3 * paper.pixelsPerMm,
      pageWidthPx = paper.widthMm * paper.pixelsPerMm,
      pageHeightPx = paper.heightMm * paper.pixelsPerMm,
      marginPx = 10 * paper.pixelsPerMm,
      axisPx = 7 * paper.pixelsPerMm,
      footerPx = 9 * paper.pixelsPerMm;

  /// Шаг крупной линии и подписей, клеток.
  static const int majorStep = 10;

  final PrintPaper paper;
  final int pixelsPerMm;
  final int cellPx;
  final int pageWidthPx;
  final int pageHeightPx;
  final int marginPx;

  /// Полоса с номерами вдоль каждой стороны сетки.
  final int axisPx;

  /// Подпись внизу листа.
  final int footerPx;

  int get gridLeftPx => marginPx + axisPx;
  int get gridTopPx => marginPx + axisPx;

  int get tileColumns => ((pageWidthPx - 2 * gridLeftPx) ~/ cellPx) ~/ majorStep * majorStep;
  int get tileRows => ((pageHeightPx - 2 * gridTopPx - footerPx) ~/ cellPx) ~/ majorStep * majorStep;

  /// Страницы по строкам сверху вниз, слева направо.
  List<PrintTile> tiles({required int columns, required int rows}) {
    if (columns <= 0 || rows <= 0) return const <PrintTile>[];
    final int tc = tileColumns;
    final int tr = tileRows;
    return <PrintTile>[
      for (int row = 0; row < rows; row += tr)
        for (int column = 0; column < columns; column += tc)
          PrintTile(
            column: column,
            row: row,
            columns: column + tc > columns ? columns - column : tc,
            rows: row + tr > rows ? rows - row : tr,
          ),
    ];
  }

  /// Страниц всего: листы схемы и листы легенды на [colors] цветов.
  int pageCount({required int columns, required int rows, required int colors}) =>
      tiles(columns: columns, rows: rows).length + LegendLayout.pageCount(colors);

  /// Абсолютные границы, кратные [majorStep], внутри `[start, end]`: для них рисуем крупную линию и номер.
  static List<int> majorLines(int start, int end) => <int>[
    for (int value = ((start + majorStep - 1) ~/ majorStep) * majorStep; value <= end; value += majorStep) value,
  ];
}

/// Легенда: всегда лист A4 (растр 10 px/мм), цвета в одну или две колонки по номерам игольницы.
abstract final class LegendLayout {
  static const PrintPaper paper = PrintPaper.a4;
  static const int pageWidthPx = 2100;
  static const int pageHeightPx = 2970;
  static const int marginPx = 100;
  static const int titlePx = 140;
  static const int footerPx = 90;
  static const int rowPx = 56;
  static const int columnGapPx = 60;

  static const int rowsPerColumn = (pageHeightPx - 2 * marginPx - titlePx - footerPx) ~/ rowPx;
  static const int columnsPerPage = 2;
  static const int rowsPerPage = rowsPerColumn * columnsPerPage;

  /// Листов легенды на [colors] цветов; для схемы без цветов лист не нужен.
  static int pageCount(int colors) => colors <= 0 ? 0 : (colors + rowsPerPage - 1) ~/ rowsPerPage;
}
