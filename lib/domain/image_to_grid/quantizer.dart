import 'dart:math' as math;

import 'package:beading/domain/palette/lab.dart';

/// Результат квантования: центры кластеров и номер кластера каждой точки.
final class Quantization {
  Quantization({required List<Lab> centers, required List<int> assignments})
    : centers = List<Lab>.unmodifiable(centers),
      assignments = List<int>.unmodifiable(assignments);

  final List<Lab> centers;
  final List<int> assignments;
}

/// Шаг 3 конвейера: квантование цветов в Lab. Median cut даёт начальные центры, k-means их уточняет.
///
/// Чистая функция точек и весов. Веса — важность точек (маска важности): тяжёлые точки сильнее тянут центры.
/// Результат детерминирован; [seed] влияет только на выбор точки для кластера, который опустел.
final class LabQuantizer {
  const LabQuantizer({this.maxIterations = 24});

  final int maxIterations;

  Quantization quantize(List<Lab> points, List<double> weights, {required int colors, int seed = 0}) {
    if (colors < 1) throw ArgumentError.value(colors, 'colors', 'не меньше 1');
    if (points.length != weights.length) throw ArgumentError('Точек и весов должно быть поровну');
    if (points.isEmpty) return Quantization(centers: const <Lab>[], assignments: const <int>[]);
    final List<double> safeWeights = <double>[for (final double w in weights) math.max(w, _minWeight)];
    final List<Lab> start = medianCut(points, safeWeights, colors);
    return _kMeans(points, safeWeights, start, seed);
  }

  static const double _minWeight = 1e-6;

  /// Median cut: делит коробку с самым большим размахом по самой растянутой оси в взвешенной медиане.
  /// Возвращает не больше [colors] центров; меньше, если различных цветов не хватает.
  List<Lab> medianCut(List<Lab> points, List<double> weights, int colors) {
    final List<List<int>> boxes = <List<int>>[List<int>.generate(points.length, (i) => i)];
    while (boxes.length < colors) {
      int bestBox = -1;
      int bestAxis = 0;
      double bestRange = 0;
      for (int b = 0; b < boxes.length; b++) {
        if (boxes[b].length < 2) continue;
        final (int axis, double range) = _widestAxis(points, boxes[b]);
        if (range > bestRange) {
          bestRange = range;
          bestBox = b;
          bestAxis = axis;
        }
      }
      if (bestBox < 0) break;
      final List<int> box = boxes[bestBox]
        ..sort((a, b) {
          final int byAxis = _axisValue(points[a], bestAxis).compareTo(_axisValue(points[b], bestAxis));
          return byAxis != 0 ? byAxis : a.compareTo(b);
        });
      double total = 0;
      for (final int i in box) {
        total += weights[i];
      }
      double running = 0;
      int split = 1;
      for (int i = 0; i < box.length - 1; i++) {
        running += weights[box[i]];
        split = i + 1;
        if (running >= total / 2) break;
      }
      // Одинаковые значения по оси нельзя разделить: сдвигаем разрез к границе значения.
      final double pivot = _axisValue(points[box[split - 1]], bestAxis);
      if (_axisValue(points[box[split]], bestAxis) == pivot) {
        int down = split;
        while (down > 0 && _axisValue(points[box[down - 1]], bestAxis) == pivot) {
          down--;
        }
        int up = split;
        while (up < box.length && _axisValue(points[box[up]], bestAxis) == pivot) {
          up++;
        }
        split = down > 0 ? down : up;
      }
      boxes
        ..[bestBox] = box.sublist(0, split)
        ..add(box.sublist(split));
    }
    return <Lab>[for (final List<int> box in boxes) _mean(points, weights, box)];
  }

  Quantization _kMeans(List<Lab> points, List<double> weights, List<Lab> start, int seed) {
    final math.Random random = math.Random(seed);
    final List<Lab> centers = <Lab>[...start];
    final List<int> assignments = List<int>.filled(points.length, 0);
    for (int iteration = 0; iteration < maxIterations; iteration++) {
      bool changed = iteration == 0;
      for (int i = 0; i < points.length; i++) {
        final int nearest = _nearest(points[i], centers);
        if (nearest != assignments[i]) {
          assignments[i] = nearest;
          changed = true;
        }
      }
      if (!changed) break;
      final List<List<int>> members = List<List<int>>.generate(centers.length, (_) => <int>[]);
      for (int i = 0; i < points.length; i++) {
        members[assignments[i]].add(i);
      }
      for (int c = 0; c < centers.length; c++) {
        centers[c] = members[c].isEmpty ? points[random.nextInt(points.length)] : _mean(points, weights, members[c]);
      }
    }
    // Кластеры без точек выбрасываем, номера уплотняем.
    final List<int> counts = List<int>.filled(centers.length, 0);
    for (final int a in assignments) {
      counts[a]++;
    }
    final List<int> remap = List<int>.filled(centers.length, -1);
    final List<Lab> kept = <Lab>[];
    for (int c = 0; c < centers.length; c++) {
      if (counts[c] > 0) {
        remap[c] = kept.length;
        kept.add(centers[c]);
      }
    }
    return Quantization(centers: kept, assignments: <int>[for (final int a in assignments) remap[a]]);
  }

  static int _nearest(Lab point, List<Lab> centers) {
    int best = 0;
    double bestDistance = double.infinity;
    for (int c = 0; c < centers.length; c++) {
      final double d = _distanceSquared(point, centers[c]);
      if (d < bestDistance) {
        bestDistance = d;
        best = c;
      }
    }
    return best;
  }

  static double _distanceSquared(Lab a, Lab b) {
    final double dl = a.l - b.l;
    final double da = a.a - b.a;
    final double db = a.b - b.b;
    return dl * dl + da * da + db * db;
  }

  static double _axisValue(Lab lab, int axis) => switch (axis) {
    0 => lab.l,
    1 => lab.a,
    _ => lab.b,
  };

  static (int, double) _widestAxis(List<Lab> points, List<int> box) {
    int bestAxis = 0;
    double bestRange = 0;
    for (int axis = 0; axis < 3; axis++) {
      double low = double.infinity;
      double high = double.negativeInfinity;
      for (final int i in box) {
        final double v = _axisValue(points[i], axis);
        low = math.min(low, v);
        high = math.max(high, v);
      }
      if (high - low > bestRange) {
        bestRange = high - low;
        bestAxis = axis;
      }
    }
    return (bestAxis, bestRange);
  }

  static Lab _mean(List<Lab> points, List<double> weights, List<int> indexes) {
    double total = 0;
    double l = 0;
    double a = 0;
    double b = 0;
    for (final int i in indexes) {
      total += weights[i];
      l += weights[i] * points[i].l;
      a += weights[i] * points[i].a;
      b += weights[i] * points[i].b;
    }
    return Lab(l / total, a / total, b / total);
  }
}
