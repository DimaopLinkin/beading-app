import 'dart:typed_data';

import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Шаги 4–5 конвейера: каждой ячейке — ближайший цвет палитры по ΔE2000, по желанию с дизерингом Флойда—Стейнберга.
///
/// Работает по индексам ячеек и соседству «вправо, вниз»: для пейота и кирпичного стежка это приближение (ошибка
/// уходит в соседей по сетке, а не по мм), на результат глаз его не видит.
final class ColorAssigner {
  const ColorAssigner();

  /// Значения `1..palette.length`; `0` — у пустых ячеек (`null`).
  Uint16List assign({
    required List<Rgb?> cells,
    required int columns,
    required int rows,
    required List<Rgb> palette,
    bool dither = false,
  }) {
    final Uint16List result = Uint16List(columns * rows);
    if (palette.isEmpty) return result;
    final List<Lab> paletteLab = <Lab>[for (final Rgb c in palette) Lab.fromRgb(c)];
    if (!dither) {
      for (int i = 0; i < result.length; i++) {
        final Rgb? color = cells[i];
        if (color != null) result[i] = _nearest(Lab.fromRgb(color), paletteLab) + 1;
      }
      return result;
    }

    // Накопленная ошибка по Lab для каждой ячейки.
    final Float64List error = Float64List(columns * rows * 3);
    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < columns; column++) {
        final int index = row * columns + column;
        final Rgb? color = cells[index];
        if (color == null) continue;
        final Lab base = Lab.fromRgb(color);
        final Lab wanted = Lab(
          (base.l + error[index * 3]).clamp(0, 100),
          base.a + error[index * 3 + 1],
          base.b + error[index * 3 + 2],
        );
        final int chosen = _nearest(wanted, paletteLab);
        result[index] = chosen + 1;
        final Lab picked = paletteLab[chosen];
        final double dl = wanted.l - picked.l;
        final double da = wanted.a - picked.a;
        final double db = wanted.b - picked.b;
        void spread(int dx, int dy, double share) {
          final int x = column + dx;
          final int y = row + dy;
          if (x < 0 || x >= columns || y >= rows || cells[y * columns + x] == null) return;
          final int target = (y * columns + x) * 3;
          error[target] += dl * share;
          error[target + 1] += da * share;
          error[target + 2] += db * share;
        }

        spread(1, 0, 7 / 16);
        spread(-1, 1, 3 / 16);
        spread(0, 1, 5 / 16);
        spread(1, 1, 1 / 16);
      }
    }
    return result;
  }

  static int _nearest(Lab target, List<Lab> palette) {
    int best = 0;
    double bestDistance = double.infinity;
    for (int i = 0; i < palette.length; i++) {
      final double d = deltaE2000(target, palette[i]);
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }
}
