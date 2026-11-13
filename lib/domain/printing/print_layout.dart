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

/// Раскладка печати схемы вышивки на листы A4 в масштабе «10 крестиков = 3 см».
///
/// Всё считается в пикселях растра 10 пикселей на миллиметр (254 dpi): клетка — ровно 30 пикселей, лист A4 — 2100×2970.
/// Страницы нарезаны по 40×80 клеток: границы кратны десяти, так что номера на краях совпадают с соседней страницей.
abstract final class PrintLayout {
  /// Пикселей на миллиметр.
  static const int pixelsPerMm = 10;

  /// Клеток в сантиметрах: 10 крестиков = 3 см, клетка 3 мм.
  static const int cellPx = 30;

  static const int pageWidthPx = 2100;
  static const int pageHeightPx = 2970;
  static const double pageWidthMm = 210;
  static const double pageHeightMm = 297;

  /// Поле листа.
  static const int marginPx = 100;

  /// Полоса с номерами вдоль каждой стороны сетки.
  static const int axisPx = 70;

  /// Подпись внизу листа.
  static const int footerPx = 90;

  /// Колонка легенды справа.
  static const int legendWidthPx = 520;
  static const int legendGapPx = 30;

  static const int tileColumns = 40;
  static const int tileRows = 80;

  /// Шаг крупной линии и подписей, клеток.
  static const int majorStep = 10;

  /// Левый верхний угол сетки на странице.
  static const int gridLeftPx = marginPx + axisPx;
  static const int gridTopPx = marginPx + axisPx;

  /// Левый край колонки легенды.
  static const int legendLeftPx = pageWidthPx - marginPx - legendWidthPx;

  /// Страницы по строкам сверху вниз, слева направо.
  static List<PrintTile> tiles({required int columns, required int rows}) {
    if (columns <= 0 || rows <= 0) return const <PrintTile>[];
    return <PrintTile>[
      for (int row = 0; row < rows; row += tileRows)
        for (int column = 0; column < columns; column += tileColumns)
          PrintTile(
            column: column,
            row: row,
            columns: column + tileColumns > columns ? columns - column : tileColumns,
            rows: row + tileRows > rows ? rows - row : tileRows,
          ),
    ];
  }

  /// Абсолютные границы, кратные [majorStep], внутри `[start, end]`: для них рисуем крупную линию и номер.
  static List<int> majorLines(int start, int end) => <int>[
    for (int value = ((start + majorStep - 1) ~/ majorStep) * majorStep; value <= end; value += majorStep) value,
  ];
}
