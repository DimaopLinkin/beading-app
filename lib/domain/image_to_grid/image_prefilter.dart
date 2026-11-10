import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/work_image.dart';

/// Стадия 1 конвейера (ADR-0004): подготовка фото до выбора цветов.
///
/// Чистая функция над [WorkImage]: возвращает новую картинку того же размера, входную не меняет.
abstract interface class ImagePrefilter {
  WorkImage apply(WorkImage image);
}

/// Сглаживание шума с сохранением краёв и чуть подтянутая насыщенность.
///
/// Двусторонний фильтр в Lab (два прохода, радиус 2) для схем до 100×100 ячеек и управляемый фильтр (O(N)) для
/// больших. Светлота не растягивается: первая версия прототипа растягивала её и «выбеливала» кожу и шерсть.
final class EdgePreservingPrefilter implements ImagePrefilter {
  const EdgePreservingPrefilter({this.sigmaRange = 9, this.saturation = 1.05, this.guidedAbovePixels = 250000})
    : assert(sigmaRange > 0, 'sigmaRange > 0'),
      assert(saturation >= 1 && saturation <= 1.1, 'saturation от 1 до 1,1');

  /// Насколько различные цвета ещё усредняются, в единицах Lab: больше — глаже, меньше — резче.
  final double sigmaRange;

  /// Множитель цветности (a, b): от 1,0 (без изменений) до 1,1.
  final double saturation;

  /// Размер рабочей картинки в пикселях, с которого вместо двустороннего берётся управляемый фильтр
  /// (схема больше 100×100 ячеек при пяти рабочих пикселях на ячейку).
  final int guidedAbovePixels;

  /// Радиус окна обоих фильтров в рабочих пикселях.
  static const int radius = 2;

  @override
  WorkImage apply(WorkImage image) {
    final int cells = image.width * image.height;
    final ({Float32List l, Float32List a, Float32List b}) filtered = cells > guidedAbovePixels
        ? _guided(image)
        : _bilateral(image);
    if (saturation != 1) {
      for (int i = 0; i < cells; i++) {
        filtered.a[i] *= saturation;
        filtered.b[i] *= saturation;
      }
    }
    return image.withColors(lightness: filtered.l, a: filtered.a, b: filtered.b);
  }

  ({Float32List l, Float32List a, Float32List b}) _bilateral(WorkImage image) {
    final int w = image.width;
    final int h = image.height;
    const int window = 2 * radius + 1;
    // Вес по расстоянию: гауссиана σ = 2 на окне 5×5.
    final Float64List spatial = Float64List(window * window);
    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        spatial[(dy + radius) * window + dx + radius] = math.exp(-(dx * dx + dy * dy) / (2 * 2.0 * 2.0));
      }
    }
    // Вес по цвету: таблица exp(-d² / 2σ²) по d² до 8·(2σ²), дальше вес ≈ 0.
    const int tableSize = 512;
    const double reach = 8;
    final double twoSigma2 = 2 * sigmaRange * sigmaRange;
    final Float64List range = Float64List(tableSize + 1);
    for (int i = 0; i <= tableSize; i++) {
      range[i] = math.exp(-i / tableSize * reach);
    }
    final double toIndex = tableSize / (reach * twoSigma2);

    Float32List l = Float32List.fromList(image.lightness);
    Float32List a = Float32List.fromList(image.a);
    Float32List b = Float32List.fromList(image.b);
    for (int pass = 0; pass < 2; pass++) {
      final Float32List nl = Float32List(w * h);
      final Float32List na = Float32List(w * h);
      final Float32List nb = Float32List(w * h);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final int i = y * w + x;
          final double cl = l[i];
          final double ca = a[i];
          final double cb = b[i];
          double sl = 0;
          double sa = 0;
          double sb = 0;
          double total = 0;
          for (int dy = -radius; dy <= radius; dy++) {
            final int yy = (y + dy).clamp(0, h - 1);
            for (int dx = -radius; dx <= radius; dx++) {
              final int j = yy * w + (x + dx).clamp(0, w - 1);
              final double dl = l[j] - cl;
              final double da = a[j] - ca;
              final double db = b[j] - cb;
              final int index = ((dl * dl + da * da + db * db) * toIndex).toInt();
              if (index > tableSize) continue;
              final double weight = spatial[(dy + radius) * window + dx + radius] * range[index];
              sl += l[j] * weight;
              sa += a[j] * weight;
              sb += b[j] * weight;
              total += weight;
            }
          }
          // Сама точка входит в окно с весом 1: total не меньше 1.
          nl[i] = sl / total;
          na[i] = sa / total;
          nb[i] = sb / total;
        }
      }
      l = nl;
      a = na;
      b = nb;
    }
    return (l: l, a: a, b: b);
  }

  /// Управляемый фильтр (He, Sun, Tang): светлота — ведущая картинка, окно усредняется ящичным фильтром за O(N).
  ({Float32List l, Float32List a, Float32List b}) _guided(WorkImage image) {
    final int w = image.width;
    final int h = image.height;
    final Float32List guide = image.lightness;
    final double eps = sigmaRange * sigmaRange;
    final Float32List meanI = _box(guide, w, h);
    final Float32List meanII = _box(_product(guide, guide), w, h);
    final Float32List variance = Float32List(w * h);
    for (int i = 0; i < w * h; i++) {
      variance[i] = meanII[i] - meanI[i] * meanI[i];
    }
    Float32List filter(Float32List p) {
      final Float32List meanP = _box(p, w, h);
      final Float32List meanIP = _box(_product(guide, p), w, h);
      final Float32List slope = Float32List(w * h);
      final Float32List offset = Float32List(w * h);
      for (int i = 0; i < w * h; i++) {
        final double covariance = meanIP[i] - meanI[i] * meanP[i];
        slope[i] = covariance / (variance[i] + eps);
        offset[i] = meanP[i] - slope[i] * meanI[i];
      }
      final Float32List meanSlope = _box(slope, w, h);
      final Float32List meanOffset = _box(offset, w, h);
      final Float32List out = Float32List(w * h);
      for (int i = 0; i < w * h; i++) {
        out[i] = meanSlope[i] * guide[i] + meanOffset[i];
      }
      return out;
    }

    return (l: filter(image.lightness), a: filter(image.a), b: filter(image.b));
  }

  static Float32List _product(Float32List x, Float32List y) {
    final Float32List out = Float32List(x.length);
    for (int i = 0; i < x.length; i++) {
      out[i] = x[i] * y[i];
    }
    return out;
  }

  /// Среднее в окне радиуса [radius] (на краях окно обрезается) через суммы по строкам и столбцам.
  static Float32List _box(Float32List data, int w, int h) {
    final Float64List horizontal = Float64List(w * h);
    for (int y = 0; y < h; y++) {
      double running = 0;
      final int base = y * w;
      for (int x = 0; x < math.min(radius, w); x++) {
        running += data[base + x];
      }
      for (int x = 0; x < w; x++) {
        if (x + radius < w) running += data[base + x + radius];
        if (x - radius - 1 >= 0) running -= data[base + x - radius - 1];
        horizontal[base + x] = running;
      }
    }
    final Float32List out = Float32List(w * h);
    for (int x = 0; x < w; x++) {
      double running = 0;
      for (int y = 0; y < math.min(radius, h); y++) {
        running += horizontal[y * w + x];
      }
      for (int y = 0; y < h; y++) {
        if (y + radius < h) running += horizontal[(y + radius) * w + x];
        if (y - radius - 1 >= 0) running -= horizontal[(y - radius - 1) * w + x];
        final int cols = (x + radius < w ? x + radius : w - 1) - (x - radius > 0 ? x - radius : 0) + 1;
        final int rows = (y + radius < h ? y + radius : h - 1) - (y - radius > 0 ? y - radius : 0) + 1;
        out[y * w + x] = running / (cols * rows);
      }
    }
    return out;
  }
}
