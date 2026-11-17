import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Подъём глубоких теней фото перед выбором ниток (T87).
///
/// В каталогах мулине почти нет очень тёмных тонов (светлота Lab 0–20), поэтому у фото с большими областями глубокой
/// тени схема выходит пятнистой и плоской. Мы заранее осветляем только глубокие тени, чтобы они попали туда, где нитки
/// есть. Кривая работает в CIELAB (D65): меняется одна светлота L, цветность a и b остаются.
abstract final class ShadowLift {
  /// Самая сильная кривая: γ = 0,5 (100 %). γ = 1 — без подъёма (0 %).
  static const double minGamma = 0.5;

  /// Выше этой светлоты кривая ничего не меняет; к ней вес подъёма плавно сходит на нет.
  static const double fadeL = 60;

  /// Кандидаты автоподбора, от слабого к сильному (0, 20, …, 100 %).
  static const List<double> autoCandidates = <double>[1.0, 0.9, 0.8, 0.7, 0.6, 0.5];

  /// Цена силы подъёма в автоподборе: к средней ΔE2000 добавляется `penaltyPerGamma * (1 − γ)`, чтобы не светлить
  /// без пользы.
  static const double penaltyPerGamma = 3;

  /// Сколько образцов берёт автоподбор (примерно 110 × 160).
  static const int sampleBudget = 17600;

  /// Сколько ближайших ниток по дешёвой ΔE76 проверяется точной ΔE2000.
  static const int _shortlist = 8;

  /// γ для силы [percent] (0..100): `1 − 0,5 · percent / 100`.
  static double gammaForPercent(int percent) => 1 - (1 - minGamma) * percent.clamp(0, 100) / 100;

  /// Обратное к [gammaForPercent], округлённое до целого процента.
  static int percentForGamma(double gamma) => ((1 - gamma) / (1 - minGamma) * 100).round().clamp(0, 100);

  /// Светлота [l] после подъёма с показателем [gamma]: `l + (100 (l/100)^γ − l) · w`, `w = ((60 − l)/60)^0,7`.
  static double liftL(double l, double gamma) {
    final double c = l.clamp(0, 100).toDouble();
    if (gamma >= 1 || c >= fadeL) return c;
    final double lifted = 100 * math.pow(c / 100, gamma).toDouble();
    final double w = math.pow((fadeL - c) / fadeL, 0.7).toDouble();
    return c + (lifted - c) * w;
  }

  /// [lab] с поднятой светлотой; a и b те же.
  static Lab liftLab(Lab lab, double gamma) => Lab(liftL(lab.l, gamma), lab.a, lab.b);

  /// Копия [image] с поднятыми тенями; при `gamma >= 1` — сам [image]. Прозрачность не меняется.
  static SourceImage liftImage(SourceImage image, double gamma) {
    if (gamma >= 1) return image;
    final Uint8List src = image.rgba;
    final Uint8List out = Uint8List.fromList(src);
    // Быстрый отсев: светлее L = 60, то есть Y ≥ ((60 + 16) / 116)³, кривая не трогает — Lab можно не считать.
    const double yLimit = 0.28127;
    final List<double> linear = _linearTable;
    final Map<int, int> memo = <int, int>{};
    for (int i = 0; i < src.length; i += 4) {
      final int r = src[i];
      final int g = src[i + 1];
      final int b = src[i + 2];
      final double y = 0.2126729 * linear[r] + 0.7151522 * linear[g] + 0.0721750 * linear[b];
      if (y >= yLimit) continue;
      final int key = (r << 16) | (g << 8) | b;
      int? packed = memo[key];
      if (packed == null) {
        final Rgb rgb = liftLab(Lab.fromRgb(Rgb(r, g, b)), gamma).toRgb();
        packed = (rgb.r << 16) | (rgb.g << 8) | rgb.b;
        memo[key] = packed;
      }
      out[i] = (packed >> 16) & 0xFF;
      out[i + 1] = (packed >> 8) & 0xFF;
      out[i + 2] = packed & 0xFF;
    }
    return SourceImage(width: image.width, height: image.height, rgba: out);
  }

  /// Автоподбор γ по фото и допустимым ниткам [threads] (их Lab).
  ///
  /// Фото уменьшается усреднением по блокам до [sampleBudget] образцов. Для каждого кандидата из [autoCandidates]
  /// образцы поднимаются, и считается средняя ΔE2000 до ближайшей нитки; счёт — она плюс [penaltyPerGamma] · (1 − γ).
  /// Побеждает меньший счёт, при равенстве — больший γ (слабее подъём).
  static double autoGamma(SourceImage image, List<Lab> threads) {
    if (threads.isEmpty) return 1;
    final List<Lab> samples = _samples(image);
    if (samples.isEmpty) return 1;
    final _ThreadIndex index = _ThreadIndex(threads);
    double bestScore = double.infinity;
    double best = 1;
    for (final double gamma in autoCandidates) {
      double sum = 0;
      for (final Lab sample in samples) {
        sum += index.nearestDeltaE(liftLab(sample, gamma));
      }
      final double score = sum / samples.length + penaltyPerGamma * (1 - gamma);
      if (score < bestScore - 1e-9) {
        bestScore = score;
        best = gamma;
      }
    }
    return best;
  }

  /// Сила в процентах для подъёма, подобранного [autoGamma] по ниткам из [entries].
  static int autoPercent(SourceImage image, List<PaletteEntry> entries) =>
      percentForGamma(autoGamma(image, <Lab>[for (final PaletteEntry e in entries) Lab.fromRgb(e.rgb)]));

  /// Образцы Lab: среднее по блокам (в sRGB, взвешенное непрозрачностью); почти прозрачные блоки пропускаются.
  static List<Lab> _samples(SourceImage image) {
    final int pixels = image.width * image.height;
    final int block = pixels <= sampleBudget ? 1 : math.max(1, math.sqrt(pixels / sampleBudget).ceil());
    final int cols = (image.width + block - 1) ~/ block;
    final int rows = (image.height + block - 1) ~/ block;
    final Uint8List rgba = image.rgba;
    final List<Lab> out = <Lab>[];
    for (int by = 0; by < rows; by++) {
      for (int bx = 0; bx < cols; bx++) {
        double r = 0;
        double g = 0;
        double b = 0;
        double a = 0;
        int count = 0;
        final int x1 = math.min(image.width, (bx + 1) * block);
        final int y1 = math.min(image.height, (by + 1) * block);
        for (int y = by * block; y < y1; y++) {
          for (int x = bx * block; x < x1; x++) {
            final int o = (y * image.width + x) * 4;
            final double w = rgba[o + 3] / 255;
            r += rgba[o] * w;
            g += rgba[o + 1] * w;
            b += rgba[o + 2] * w;
            a += w;
            count++;
          }
        }
        if (count == 0 || a / count < 0.5) continue;
        out.add(Lab.fromRgb(Rgb((r / a).round(), (g / a).round(), (b / a).round())));
      }
    }
    return out;
  }

  static final List<double> _linearTable = List<double>.generate(256, (c) {
    final double s = c / 255;
    return s <= 0.04045 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }, growable: false);
}

/// Ближайшая нитка по ΔE2000 с предварительным отбором по ΔE76: дёшево отсеивает почти все позиции.
final class _ThreadIndex {
  _ThreadIndex(this._labs)
    : _l = Float64List.fromList(<double>[for (final Lab c in _labs) c.l]),
      _a = Float64List.fromList(<double>[for (final Lab c in _labs) c.a]),
      _b = Float64List.fromList(<double>[for (final Lab c in _labs) c.b]),
      _dist = Float64List(ShadowLift._shortlist),
      _near = Int32List(ShadowLift._shortlist);

  final List<Lab> _labs;
  final Float64List _l;
  final Float64List _a;
  final Float64List _b;
  final Float64List _dist;
  final Int32List _near;

  double nearestDeltaE(Lab target) {
    final int n = math.min(ShadowLift._shortlist, _labs.length);
    int filled = 0;
    for (int i = 0; i < _labs.length; i++) {
      final double dl = _l[i] - target.l;
      final double da = _a[i] - target.a;
      final double db = _b[i] - target.b;
      final double d = dl * dl + da * da + db * db;
      if (filled == n && d >= _dist[n - 1]) continue;
      int at = filled < n ? filled++ : n - 1;
      while (at > 0 && _dist[at - 1] > d) {
        _dist[at] = _dist[at - 1];
        _near[at] = _near[at - 1];
        at--;
      }
      _dist[at] = d;
      _near[at] = i;
    }
    double best = double.infinity;
    for (int k = 0; k < filled; k++) {
      best = math.min(best, deltaE2000(target, _labs[_near[k]]));
    }
    return best;
  }
}
