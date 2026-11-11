import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid/mm.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Картинка рабочего разрешения в Lab: по нескольку пикселей на ячейку схемы (ADR-0004, стадия 1).
///
/// Все фильтры подготовки фото работают на ней, а не на исходнике в 12 Мпикс. Маска важности лежит в том же
/// разрешении: маска исходника весила бы 48 МБ.
final class WorkImage {
  WorkImage({
    required this.width,
    required this.height,
    required this.lightness,
    required this.a,
    required this.b,
    required this.alpha,
    required this.importance,
    this.scale = 1,
  }) {
    if (width < 1) throw ArgumentError.value(width, 'width', 'не меньше 1');
    if (height < 1) throw ArgumentError.value(height, 'height', 'не меньше 1');
    final int count = width * height;
    for (final (String name, Float32List data) in <(String, Float32List)>[
      ('lightness', lightness),
      ('a', a),
      ('b', b),
      ('alpha', alpha),
      ('importance', importance),
    ]) {
      if (data.length != count) throw ArgumentError.value(data.length, name, 'ожидалось $count значений');
    }
  }

  /// Уменьшает [image] по площади до рабочего разрешения схемы [columns] × [rows].
  ///
  /// [scale] — рабочих пикселей на сторону ячейки; по умолчанию [scaleFor] (черновик берёт меньше, см. [draftScale]).
  ///
  /// Усреднение идёт в линейном свете, с весом непрозрачности: смесь чёрного и белого 50/50 даёт sRGB ≈ 188, а не 128.
  /// Размер рабочей картинки повторяет габариты схемы в миллиметрах, поэтому сдвиг рядов пейота и кирпичного стежка
  /// остаётся тем же, что в CellSampler.
  factory WorkImage.fromSource({
    required SourceImage image,
    required GridGeometry geometry,
    required CellMetrics metrics,
    required int columns,
    required int rows,
    Float32List? importance,
    int? scale,
  }) {
    if (columns < 1 || rows < 1) throw ArgumentError('Размер сетки не меньше 1×1');
    if (importance != null && importance.length != image.width * image.height) {
      throw ArgumentError.value(importance.length, 'importance', 'ожидалось ${image.width * image.height} весов');
    }
    final int s = scale ?? scaleFor(columns: columns, rows: rows);
    final MmSize extent = geometry.extent(metrics, columns: columns, rows: rows);
    final int width = columns * s;
    final int height = math.max(1, (width * extent.height / extent.width).round());
    return WorkImage._downscale(image, importance, width, height, s);
  }

  /// Рабочих пикселей на сторону ячейки в черновике предпросмотра (T58): расчёт в разы быстрее, цвета и границы грубее.
  static const int draftScale = 2;

  /// Сколько рабочих пикселей на сторону ячейки: 6 для мелких схем, 3 для крупных.
  static int scaleFor({required int columns, required int rows}) {
    final int cells = columns * rows;
    if (cells <= 2500) return 6;
    if (cells <= 10000) return 5;
    if (cells <= 30000) return 4;
    return 3;
  }

  final int width;
  final int height;

  /// Рабочих пикселей на сторону ячейки схемы (1, если картинка собрана не из схемы).
  final int scale;

  /// Каналы Lab и непрозрачность 0..1 по рядам сверху вниз. У прозрачных пикселей цвет — Lab чёрного.
  final Float32List lightness;
  final Float32List a;
  final Float32List b;
  final Float32List alpha;

  /// Вес важности на пиксель; без маски везде 1.
  final Float32List importance;

  /// Копия с другими цветами: прозрачность и маска переходят как есть.
  WorkImage withColors({required Float32List lightness, required Float32List a, required Float32List b}) => WorkImage(
    width: width,
    height: height,
    lightness: lightness,
    a: a,
    b: b,
    alpha: alpha,
    importance: importance,
    scale: scale,
  );

  /// Пиксели sRGB для [CellSampler]: ячейка берёт средний цвет из рабочей картинки.
  SourceImage toSourceImage() {
    final Uint8List rgba = Uint8List(width * height * 4);
    for (int i = 0; i < width * height; i++) {
      final Rgb rgb = Lab(lightness[i], a[i], b[i]).toRgb();
      rgba[i * 4] = rgb.r;
      rgba[i * 4 + 1] = rgb.g;
      rgba[i * 4 + 2] = rgb.b;
      rgba[i * 4 + 3] = (alpha[i] * 255).round().clamp(0, 255);
    }
    return SourceImage(width: width, height: height, rgba: rgba);
  }

  static final Float32List _linearTable = _buildLinearTable();

  static Float32List _buildLinearTable() {
    final Float32List table = Float32List(256);
    for (int v = 0; v < 256; v++) {
      table[v] = Rgb(v, v, v).linear.$1;
    }
    return table;
  }

  factory WorkImage._downscale(SourceImage image, Float32List? mask, int width, int height, int scale) {
    final _Spans xs = _Spans(image.width, width);
    final _Spans ys = _Spans(image.height, height);
    // Проход по строкам: суммы по горизонтали для каждой строки исходника. Каналы: R·α, G·α, B·α, α, важность.
    const int channels = 5;
    final Float32List rows = Float32List(image.height * width * channels);
    final Uint8List rgba = image.rgba;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < width; x++) {
        double r = 0;
        double g = 0;
        double bl = 0;
        double alphaSum = 0;
        double weight = 0;
        for (int sx = xs.first[x]; sx <= xs.last[x]; sx++) {
          final double cover = xs.cover(x, sx);
          final int pixel = y * image.width + sx;
          final int offset = pixel * 4;
          final double alpha = rgba[offset + 3] / 255 * cover;
          r += _linearTable[rgba[offset]] * alpha;
          g += _linearTable[rgba[offset + 1]] * alpha;
          bl += _linearTable[rgba[offset + 2]] * alpha;
          alphaSum += alpha;
          weight += (mask?[pixel] ?? 1) * cover;
        }
        final int at = (y * width + x) * channels;
        rows[at] = r;
        rows[at + 1] = g;
        rows[at + 2] = bl;
        rows[at + 3] = alphaSum;
        rows[at + 4] = weight;
      }
    }
    final int count = width * height;
    final Float32List lightness = Float32List(count);
    final Float32List a = Float32List(count);
    final Float32List b = Float32List(count);
    final Float32List alpha = Float32List(count);
    final Float32List importance = Float32List(count);
    final Float64List sum = Float64List(channels);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        sum.fillRange(0, channels, 0);
        for (int sy = ys.first[y]; sy <= ys.last[y]; sy++) {
          final double cover = ys.cover(y, sy);
          final int at = (sy * width + x) * channels;
          for (int c = 0; c < channels; c++) {
            sum[c] += rows[at + c] * cover;
          }
        }
        final double area = xs.size(x) * ys.size(y);
        final int i = y * width + x;
        alpha[i] = (sum[3] / area).clamp(0, 1).toDouble();
        importance[i] = sum[4] / area;
        final Lab lab = sum[3] <= 0
            ? const Lab(0, 0, 0)
            : _labFromLinear(sum[0] / sum[3], sum[1] / sum[3], sum[2] / sum[3]);
        lightness[i] = lab.l;
        a[i] = lab.a;
        b[i] = lab.b;
      }
    }
    return WorkImage(
      width: width,
      height: height,
      lightness: lightness,
      a: a,
      b: b,
      alpha: alpha,
      importance: importance,
      scale: scale,
    );
  }

  static Lab _labFromLinear(double r, double g, double b) {
    final double x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b;
    final double y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b;
    final double z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b;
    final double fx = _f(x / 0.95047);
    final double fy = _f(y);
    final double fz = _f(z / 1.08883);
    return Lab(116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
  }

  static double _f(double t) {
    const double delta = 6 / 29;
    return t > delta * delta * delta ? math.pow(t, 1 / 3).toDouble() : t / (3 * delta * delta) + 4 / 29;
  }
}

/// Разбиение одной оси исходника на [target] равных отрезков: какие пиксели и с какой долей покрывает каждый.
final class _Spans {
  _Spans(this.source, this.target) : _step = source / target, first = Int32List(target), last = Int32List(target) {
    for (int i = 0; i < target; i++) {
      first[i] = math.min(source - 1, (i * _step + 1e-9).floor());
      last[i] = math.min(source - 1, math.max(first[i], ((i + 1) * _step - 1e-9).ceil() - 1));
    }
  }

  final int source;
  final int target;
  final double _step;
  final Int32List first;
  final Int32List last;

  /// Длина отрезка [i] в пикселях исходника.
  double size(int i) => _step;

  /// Часть пикселя [pixel], попавшая в отрезок [i].
  double cover(int i, int pixel) =>
      math.max(0, math.min((i + 1) * _step, pixel + 1.0) - math.max(i * _step, pixel.toDouble()));
}
