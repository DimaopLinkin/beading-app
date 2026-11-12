import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/palette/lab.dart';

/// Цена каждого цвета палитры для каждой клетки (ADR-0004, п. 3): средняя разница (Евклид в Lab, ΔE76) рабочих
/// пикселей клетки до цвета.
///
/// Два вида (T69). **Плотная** таблица — строка клетки из `colorCount` подряд идущих чисел, клетки по рядам слева
/// направо; точна для всех цветов, но весит клетки × цвета × 4 байта. Когда это больше [denseBudget] (вышивка 200 см:
/// 4 млн клеток × 120 цветов), разметчик строит **разреженную** таблицу ([CellCosts.sparse]): для клетки хранятся
/// точные цены нескольких цветов-кандидатов, а цены остальных оцениваются сверху по среднему цвету клетки.
///
/// У пустых клеток (прозрачных, номер 0 в сетке) все цены равны 0 и ничего не значат: шаги пропускают клетки с номером 0.
///
/// Нужна стадиям после разметки: перекраска клетки выбирает второй по цене цвет, а не просто цвет соседа.
final class CellCosts {
  /// Плотная таблица: [values] — `columns × rows × colorCount` чисел.
  CellCosts({required this.columns, required this.rows, required this.colorCount, required this.values})
    : _slots = 0,
      _candidates = _emptyCandidates,
      _candidateCosts = _emptyCosts,
      _candidateCounts = _emptyCounts,
      _mean = _emptyCosts,
      _spread = _emptyCosts,
      _palette = _emptyPalette {
    if (values.length != columns * rows * colorCount) {
      throw ArgumentError.value(values.length, 'values', 'ожидалось ${columns * rows * colorCount} чисел');
    }
  }

  /// Разреженная таблица: на клетку до [slots] кандидатов.
  ///
  /// [candidates] и [candidateCosts] — по [slots] чисел на клетку (номер цвета с нуля и его точная цена),
  /// [candidateCounts] — сколько из них занято. [mean] — средний Lab клетки (по 3 числа), [spread] — средняя
  /// разница пикселей клетки до этого среднего (отрицательная у пустой клетки), [palette] — Lab цветов палитры.
  CellCosts.sparse({
    required this.columns,
    required this.rows,
    required this.colorCount,
    required int slots,
    required Uint16List candidates,
    required Float32List candidateCosts,
    required Uint8List candidateCounts,
    required Float32List mean,
    required Float32List spread,
    required List<Lab> palette,
  }) : values = _emptyCosts,
       _slots = slots,
       _candidates = candidates,
       _candidateCosts = candidateCosts,
       _candidateCounts = candidateCounts,
       _mean = mean,
       _spread = spread,
       _palette = _paletteArray(palette) {
    final int cells = columns * rows;
    if (slots < 1 || slots > 255) throw ArgumentError.value(slots, 'slots', 'от 1 до 255');
    if (candidates.length != cells * slots || candidateCosts.length != cells * slots) {
      throw ArgumentError('ожидалось ${cells * slots} кандидатов');
    }
    if (candidateCounts.length != cells || spread.length != cells || mean.length != cells * 3) {
      throw ArgumentError('размеры по клеткам не сходятся');
    }
    if (palette.length != colorCount) throw ArgumentError.value(palette.length, 'palette', 'ожидалось $colorCount');
  }

  /// Сколько чисел «клетка × цвет» таблица держит плотной; больше — разреженная. Это 32 млн чисел по 4 байта.
  static const int denseBudget = 32 * 1000 * 1000;

  /// Кандидатов на клетку в разреженной таблице для [cells] клеток: сколько влезает в [budget], от 4 до 12.
  static int slotsFor(int cells, {int budget = denseBudget}) => (budget ~/ math.max(1, cells)).clamp(4, 12);

  static final Float32List _emptyCosts = Float32List(0);
  static final Uint16List _emptyCandidates = Uint16List(0);
  static final Uint8List _emptyCounts = Uint8List(0);
  static final Float64List _emptyPalette = Float64List(0);

  static Float64List _paletteArray(List<Lab> palette) {
    final Float64List out = Float64List(palette.length * 3);
    for (int i = 0; i < palette.length; i++) {
      out[i * 3] = palette[i].l;
      out[i * 3 + 1] = palette[i].a;
      out[i * 3 + 2] = palette[i].b;
    }
    return out;
  }

  final int columns;
  final int rows;
  final int colorCount;

  /// Плотная таблица; у разреженной пуста.
  final Float32List values;

  final int _slots;
  final Uint16List _candidates;
  final Float32List _candidateCosts;
  final Uint8List _candidateCounts;
  final Float32List _mean;
  final Float32List _spread;
  final Float64List _palette;

  /// Таблица разреженная: точны только цены кандидатов клетки.
  bool get isSparse => _slots > 0;

  /// Сколько цветов-кандидатов у клетки [cell] (у плотной таблицы — все цвета).
  int candidateCount(int cell) => isSparse ? _candidateCounts[cell] : colorCount;

  /// Номер [i]-го кандидата клетки [cell] (цвет с нуля).
  int candidateAt(int cell, int i) => isSparse ? _candidates[cell * _slots + i] : i;

  /// Цена цвета [color] (с нуля) для клетки по номеру [cell] = ряд × столбцов + столбец.
  ///
  /// У разреженной таблицы для не-кандидата это оценка сверху: расстояние от среднего цвета клетки до цвета плюс
  /// разброс пикселей клетки (неравенство треугольника), поэтому кандидаты всегда не дороже её.
  double at(int cell, int color) {
    if (!isSparse) return values[cell * colorCount + color];
    final double spread = _spread[cell];
    if (spread < 0) return 0;
    final int base = cell * _slots;
    final int count = _candidateCounts[cell];
    for (int i = 0; i < count; i++) {
      if (_candidates[base + i] == color) return _candidateCosts[base + i];
    }
    return _distanceToMean(cell, color) + spread;
  }

  double _distanceToMean(int cell, int color) {
    final double dl = _mean[cell * 3] - _palette[color * 3];
    final double da = _mean[cell * 3 + 1] - _palette[color * 3 + 1];
    final double db = _mean[cell * 3 + 2] - _palette[color * 3 + 2];
    return math.sqrt(dl * dl + da * da + db * db);
  }

  /// Цвет с наименьшей ценой для клетки (с нуля); при равенстве — с меньшим номером.
  ///
  /// У разреженной таблицы выбирается среди кандидатов; если их не осталось — среди всех по оценке.
  int cheapest(int cell) {
    if (isSparse) {
      final int count = _candidateCounts[cell];
      if (count > 0 && _spread[cell] >= 0) {
        final int base = cell * _slots;
        int best = _candidates[base];
        double bestCost = _candidateCosts[base];
        for (int i = 1; i < count; i++) {
          final int c = _candidates[base + i];
          final double cost = _candidateCosts[base + i];
          if (cost < bestCost || (cost == bestCost && c < best)) {
            bestCost = cost;
            best = c;
          }
        }
        return best;
      }
    }
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
  ///
  /// У разреженной таблицы кандидаты переименовываются, убранные цвета отбрасываются; клетка, потерявшая всех
  /// кандидатов, оценивается по среднему цвету.
  CellCosts select(List<int> order) {
    final int cells = columns * rows;
    if (!isSparse) {
      final Float32List out = Float32List(cells * order.length);
      for (int cell = 0; cell < cells; cell++) {
        for (int n = 0; n < order.length; n++) {
          out[cell * order.length + n] = at(cell, order[n]);
        }
      }
      return CellCosts(columns: columns, rows: rows, colorCount: order.length, values: out);
    }
    final Int32List renamed = Int32List(colorCount)..fillRange(0, colorCount, -1);
    for (int n = order.length - 1; n >= 0; n--) {
      renamed[order[n]] = n;
    }
    final Float64List palette = Float64List(order.length * 3);
    for (int n = 0; n < order.length; n++) {
      palette[n * 3] = _palette[order[n] * 3];
      palette[n * 3 + 1] = _palette[order[n] * 3 + 1];
      palette[n * 3 + 2] = _palette[order[n] * 3 + 2];
    }
    final Uint16List candidates = Uint16List(cells * _slots);
    final Float32List costs = Float32List(cells * _slots);
    final Uint8List counts = Uint8List(cells);
    for (int cell = 0; cell < cells; cell++) {
      final int base = cell * _slots;
      int kept = 0;
      for (int i = 0; i < _candidateCounts[cell]; i++) {
        final int n = renamed[_candidates[base + i]];
        if (n < 0) continue;
        candidates[base + kept] = n;
        costs[base + kept] = _candidateCosts[base + i];
        kept++;
      }
      counts[cell] = kept;
    }
    return CellCosts._sparseRaw(
      columns: columns,
      rows: rows,
      colorCount: order.length,
      slots: _slots,
      candidates: candidates,
      candidateCosts: costs,
      candidateCounts: counts,
      mean: _mean,
      spread: _spread,
      palette: palette,
    );
  }

  CellCosts._sparseRaw({
    required this.columns,
    required this.rows,
    required this.colorCount,
    required int slots,
    required Uint16List candidates,
    required Float32List candidateCosts,
    required Uint8List candidateCounts,
    required Float32List mean,
    required Float32List spread,
    required Float64List palette,
  }) : values = _emptyCosts,
       _slots = slots,
       _candidates = candidates,
       _candidateCosts = candidateCosts,
       _candidateCounts = candidateCounts,
       _mean = mean,
       _spread = spread,
       _palette = palette;
}
