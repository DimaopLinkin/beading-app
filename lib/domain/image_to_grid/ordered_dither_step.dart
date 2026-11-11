import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/cell_neighbors.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/gradient_mask.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:equatable/equatable.dart';

/// Шаг «плавные переходы» (T57): упорядоченный дизеринг (матрица Байера 2×2 или 4×4) только под маской градиентов
/// ([gradientMask]); вне её клетки не меняются.
///
/// Для клетки под маской берутся два ближайших цвета палитры `a` и `b`; доля `t` — где цвет клетки лежит на отрезке
/// от `a` к `b` (проекция в Lab). Клетка получает `b`, если `t` больше порога Байера в её позиции, иначе `a`. Поэтому:
/// - у клетки, цвет которой совпал с цветом палитры, `t = 0`, и она остаётся собой: на однотонной области дизеринг не
///   создаёт ни одной клетки другого цвета;
/// - цвета палитры не появляются и не исчезают: шаг только выбирает между уже имеющимися;
/// - клетки, которые очистка уже закрасила цветом вне пары `a` и `b`, не трогаются.
///
/// Шаг ставят **последним**: очистка «конфетти» после него стёрла бы узор.
final class OrderedDitherStep extends Equatable implements PatternStep {
  const OrderedDitherStep({
    this.matrixSize = 4,
    this.minShare = 0.12,
    this.minPairDeltaE = 3,
    this.maxPairDeltaE = 28,
    this.maxResidual = 7,
  }) : assert(matrixSize == 2 || matrixSize == 4, 'матрица Байера 2×2 или 4×4');

  /// Сторона матрицы Байера: 2 или 4.
  final int matrixSize;

  /// Доля второго цвета меньше этой не рисуется: так шум в ровных местах не даёт «зёрен».
  final double minShare;

  /// Пара цветов ближе этого неразличима, дальше — это уже контур, а не переход (ΔE76).
  final double minPairDeltaE;
  final double maxPairDeltaE;

  /// Насколько цвет клетки может отстоять от отрезка пары: больше — это другой оттенок, а не смесь пары (ΔE76).
  final double maxResidual;

  @override
  List<Object?> get props => <Object?>[matrixSize, minShare, minPairDeltaE, maxPairDeltaE, maxResidual];

  /// Порог Байера для столбца [column] и ряда [row]: числа `(k + 0,5) / n²` без повторов.
  ///
  /// Матрица ложится на пары соседних клеток ряда (`column ~/ 2`), а не на отдельные клетки: второй цвет всегда
  /// выкладывается парой, и «зёрна» из одиночных клеток не получаются.
  double threshold(int column, int row) {
    final int n = matrixSize;
    final List<int> matrix = n == 2 ? _bayer2 : _bayer4;
    return (matrix[(row % n) * n + (column ~/ 2) % n] + 0.5) / (n * n);
  }

  static const List<int> _bayer2 = <int>[0, 2, 3, 1];
  static const List<int> _bayer4 = <int>[0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

  @override
  GeneratedPattern apply(GeneratedPattern pattern, PatternStepContext context) {
    final List<Rgb?>? colors = context.cellColors;
    final Grid grid = pattern.grid;
    if (colors == null || pattern.palette.length < 2) return pattern;
    final int columns = grid.width;
    final int rows = grid.height;
    final Uint8List mask = gradientMask(cellColors: colors, columns: columns, rows: rows);
    final List<Lab> palette = <Lab>[for (final e in pattern.palette) Lab.fromRgb(e.rgb)];
    final Uint16List cells = Uint16List.fromList(grid.cells);
    for (int cell = 0; cell < cells.length; cell++) {
      final Rgb? color = colors[cell];
      if (mask[cell] == 0 || color == null || cells[cell] == 0) continue;
      final Lab target = Lab.fromRgb(color);
      int a = -1;
      int b = -1;
      double da = double.infinity;
      double db = double.infinity;
      for (int c = 0; c < palette.length; c++) {
        final double d = _distance(target, palette[c]);
        if (d < da) {
          b = a;
          db = da;
          a = c;
          da = d;
        } else if (d < db) {
          b = c;
          db = d;
        }
      }
      final int current = cells[cell] - 1;
      if (b < 0 || (current != a && current != b)) continue;
      final double pair = _distance(palette[a], palette[b]);
      if (pair < minPairDeltaE || pair > maxPairDeltaE) continue;
      final double t = _share(target, palette[a], palette[b], pair);
      final Lab onSegment = Lab.lerp(palette[a], palette[b], t);
      if (_distance(target, onSegment) > maxResidual) continue;
      final bool second = t >= minShare && t > threshold(cell % columns, cell ~/ columns);
      cells[cell] = (second ? b : a) + 1;
    }
    // Узор не должен оставлять одиночных клеток: клетка, ставшая одиночной из-за дизеринга, возвращается к первому цвету.
    final Uint16List before = Uint16List.fromList(grid.cells);
    final CellNeighbors neighbors = CellNeighbors.of(geometry: context.geometry, columns: columns, rows: rows);
    for (int cell = 0; cell < cells.length; cell++) {
      if (cells[cell] == before[cell] || cells[cell] == 0) continue;
      bool alone = true;
      for (int n = 0; n < neighbors.count(cell); n++) {
        if (cells[neighbors.at(cell, n)] == cells[cell]) {
          alone = false;
          break;
        }
      }
      if (alone) cells[cell] = before[cell];
    }
    return GeneratedPattern(
      grid: Grid.fromCells(width: columns, height: rows, cells: cells),
      palette: pattern.palette,
      stats: pattern.stats,
    );
  }

  static double _distance(Lab x, Lab y) {
    final double dl = x.l - y.l;
    final double da = x.a - y.a;
    final double db = x.b - y.b;
    return math.sqrt(dl * dl + da * da + db * db);
  }

  /// Доля пути от [from] к [to], на которой лежит проекция [target]; от 0 до 1.
  static double _share(Lab target, Lab from, Lab to, double length) {
    final double dot =
        (target.l - from.l) * (to.l - from.l) +
        (target.a - from.a) * (to.a - from.a) +
        (target.b - from.b) * (to.b - from.b);
    return (dot / (length * length)).clamp(0, 1).toDouble();
  }
}
