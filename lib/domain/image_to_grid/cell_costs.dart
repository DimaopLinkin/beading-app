import 'dart:typed_data';

/// Цена каждого цвета палитры для каждой клетки (ADR-0004, п. 3): средняя разница (Евклид в Lab, ΔE76) рабочих
/// пикселей клетки до цвета. Строка клетки — `colorCount` подряд идущих чисел, клетки по рядам слева направо.
///
/// Нужна стадиям после разметки: перекраска клетки выбирает второй по цене цвет, а не просто цвет соседа.
final class CellCosts {
  CellCosts({required this.columns, required this.rows, required this.colorCount, required this.values}) {
    if (values.length != columns * rows * colorCount) {
      throw ArgumentError.value(values.length, 'values', 'ожидалось ${columns * rows * colorCount} чисел');
    }
  }

  final int columns;
  final int rows;
  final int colorCount;
  final Float32List values;

  /// Цена цвета [color] (с нуля) для клетки по номеру [cell] = ряд × столбцов + столбец.
  double at(int cell, int color) => values[cell * colorCount + color];

  /// Цвет с наименьшей ценой для клетки (с нуля); при равенстве — с меньшим номером.
  int cheapest(int cell) {
    int best = 0;
    double bestCost = double.infinity;
    for (int c = 0; c < colorCount; c++) {
      final double cost = at(cell, c);
      if (cost < bestCost) {
        bestCost = cost;
        best = c;
      }
    }
    return best;
  }

  /// Столбцы [order] в новом порядке: после уплотнения палитры цены остаются к своим цветам.
  CellCosts select(List<int> order) {
    final Float32List out = Float32List(columns * rows * order.length);
    for (int cell = 0; cell < columns * rows; cell++) {
      for (int n = 0; n < order.length; n++) {
        out[cell * order.length + n] = at(cell, order[n]);
      }
    }
    return CellCosts(columns: columns, rows: rows, colorCount: order.length, values: out);
  }
}
