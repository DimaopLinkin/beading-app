import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';

/// Сила края в каждой клетке: наибольший перепад цвета (Lab) между рабочими пикселями на расстоянии в два пикселя
/// внутри участка клетки, как `edge_strength` в прототипе A08.
///
/// Очистка слабее там, где край сильный: глаза, блики и контуры не должны стираться вместе с шумом.
Float32List cellEdges(WorkImage work, CellRegions regions) {
  final int width = work.width;
  final int height = work.height;
  final Float32List out = Float32List(regions.columns * regions.rows);
  double dist(int i, int j) {
    final double dl = work.lightness[i] - work.lightness[j];
    final double da = work.a[i] - work.a[j];
    final double db = work.b[i] - work.b[j];
    return math.sqrt(dl * dl + da * da + db * db);
  }

  for (int cell = 0; cell < out.length; cell++) {
    double best = 0;
    for (int y = regions.top(cell); y < regions.bottom(cell); y++) {
      for (int x = regions.left(cell); x < regions.right(cell); x++) {
        final int i = y * width + x;
        final double gx = x > 0 && x < width - 1 ? dist(i - 1, i + 1) : 0;
        final double gy = y > 0 && y < height - 1 ? dist(i - width, i + width) : 0;
        best = math.max(best, math.sqrt(gx * gx + gy * gy));
      }
    }
    out[cell] = best;
  }
  return out;
}
