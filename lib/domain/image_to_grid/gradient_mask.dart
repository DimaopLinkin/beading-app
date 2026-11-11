import 'dart:typed_data';

import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Маска плавных градиентов на уровне клеток (T57): `1` — клетка лежит на ровном плавном переходе (небо на закате,
/// скула, фон-«виньетка»), где дизеринг уместен; `0` — всё остальное, там цвет клетки остаётся как выбрал конвейер.
///
/// Клетка попадает в маску, если выполняются оба условия:
/// - низкий контраст: ни с одним из четырёх соседей она не различается больше чем на [maxStep] (ΔE76 в Lab), то есть
///   рядом нет края;
/// - монотонный перепад светлоты: вдоль строки или вдоль столбца на пять клеток вокруг светлота идёт в одну сторону
///   (шум до [noise] не считается), а набирает от [minRange] до `4 × maxStep`: однотонная область не градиент.
///
/// Чистая функция: тот же вход даёт ту же маску.
Uint8List gradientMask({
  required List<Rgb?> cellColors,
  required int columns,
  required int rows,
  double maxStep = 9,
  double minRange = 2,
  double noise = 1.5,
}) {
  if (cellColors.length != columns * rows) {
    throw ArgumentError.value(cellColors.length, 'cellColors', 'ожидалось ${columns * rows} цветов');
  }
  final List<Lab?> lab = <Lab?>[for (final Rgb? c in cellColors) c == null ? null : Lab.fromRgb(c)];
  double distance(Lab a, Lab b) {
    final double dl = a.l - b.l;
    final double da = a.a - b.a;
    final double db = a.b - b.b;
    return dl * dl + da * da + db * db;
  }

  final double maxStepSquared = maxStep * maxStep;

  // Низкий контраст: дальше всех соседей клетки не больше maxStep.
  final Uint8List smooth = Uint8List(lab.length);
  for (int row = 0; row < rows; row++) {
    for (int column = 0; column < columns; column++) {
      final Lab? here = lab[row * columns + column];
      if (here == null) continue;
      bool flat = true;
      for (final (int dx, int dy) in const <(int, int)>[(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final int x = column + dx;
        final int y = row + dy;
        if (x < 0 || y < 0 || x >= columns || y >= rows) continue;
        final Lab? other = lab[y * columns + x];
        if (other == null || distance(here, other) > maxStepSquared) {
          flat = false;
          break;
        }
      }
      if (flat) smooth[row * columns + column] = 1;
    }
  }

  // Монотонный перепад светлоты на пяти клетках вдоль строки или столбца.
  bool monotone(int column, int row, int dx, int dy) {
    final List<double> l = <double>[];
    for (int k = -2; k <= 2; k++) {
      final int x = column + dx * k;
      final int y = row + dy * k;
      if (x < 0 || y < 0 || x >= columns || y >= rows || smooth[y * columns + x] == 0) return false;
      l.add(lab[y * columns + x]!.l);
    }
    final double total = l.last - l.first;
    if (total.abs() < minRange || total.abs() > 4 * maxStep) return false;
    final double sign = total.sign;
    for (int i = 1; i < l.length; i++) {
      if ((l[i] - l[i - 1]) * sign < -noise) return false;
    }
    return true;
  }

  final Uint8List mask = Uint8List(lab.length);
  for (int row = 0; row < rows; row++) {
    for (int column = 0; column < columns; column++) {
      if (smooth[row * columns + column] == 0) continue;
      if (monotone(column, row, 1, 0) || monotone(column, row, 0, 1)) mask[row * columns + column] = 1;
    }
  }
  return mask;
}
