import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/palette_constraint.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:equatable/equatable.dart';

/// Что нужно строителю палитры.
final class PaletteRequest {
  const PaletteRequest({
    required this.work,
    required this.maxColors,
    required this.constraint,
    this.seed = 0,
    this.regions,
    this.skinPixels,
  });

  final WorkImage work;

  /// Сколько цветов самое большее.
  final int maxColors;

  final PaletteConstraint constraint;
  final int seed;

  /// Клетки схемы в рабочих пикселях. С ними строитель проверяет палитру на клетках: цвет, который не выиграл ни одной
  /// клетки (блики мельче клетки), заменяется цветом самой плохо покрытой клетки.
  final CellRegions? regions;

  /// Пиксели кожи на лицах (единицы, размер рабочей картинки) или `null`, если лиц нет (T54).
  final Uint8List? skinPixels;
}

/// Стадия 2 конвейера (ADR-0004): палитра по рабочим пикселям, с привязкой к каталогу или списку внутри.
abstract interface class PaletteBuilder {
  List<PaletteEntry> build(PaletteRequest request);
}

/// Палитра по пикселям: взвешенный k-means++ в Lab по выборке, резерв акцентов, k-medoids по каталогу.
///
/// - Выборка до [sampleSize] пикселей, детерминированно по зерну; вес пикселя = маска важности × контраст
///   (детали важнее ровного фона).
/// - Около 1/5 палитры — резерв акцентов: группа пикселей площадью не меньше [accentMinCells] клеток, которая дальше
///   [accentDeltaE] (ΔE2000) от всех цветов, получает свой цвет (глаза, блики, губы).
/// - При ограничении каталогом или списком центры сразу привязываются к разным позициям (k-medoids): повторов нет,
///   число цветов равно заданному, если кандидатов хватает.
final class AccentPaletteBuilder extends Equatable implements PaletteBuilder {
  const AccentPaletteBuilder({
    this.sampleSize = 20000,
    this.accentDeltaE = 12,
    this.accentMinCells = 2,
    this.iterations = 20,
    this.medoidIterations = 8,
  });

  final int sampleSize;
  final double accentDeltaE;
  final double accentMinCells;
  final int iterations;
  final int medoidIterations;

  @override
  List<Object?> get props => <Object?>[sampleSize, accentDeltaE, accentMinCells, iterations, medoidIterations];

  @override
  List<PaletteEntry> build(PaletteRequest request) {
    final List<PaletteEntry>? candidates = request.constraint.candidates;
    if (candidates != null && candidates.length <= request.maxColors) return candidates;

    final _Sample sample = _takeSample(request.work, request.seed, sampleSize);
    if (sample.count == 0) return const <PaletteEntry>[];

    final int k = request.maxColors;
    // Резерв акцентов: при двух цветах и меньше всё отдаём основной палитре.
    final int base = k <= 2 ? k : math.max(2, k - math.max(1, k ~/ 5));
    final math.Random random = math.Random(request.seed);
    final double minGroup = _minGroup(sample, request.work.scale);
    List<Lab> centers = _kMeans(sample, base, random, minGroup);
    centers = _addAccents(sample, centers, k, minGroup);

    final CellRegions? regions = request.regions;
    final _CellMeans? cells = regions == null ? null : _CellMeans.of(request.work, regions);
    if (candidates == null) {
      if (cells != null) centers = _reseed<Lab>(centers, (c) => c, (want, current) => want, cells);
      return <PaletteEntry>{for (final Lab c in centers) PaletteEntry(rgb: c.toRgb())}.toList();
    }
    final List<PaletteEntry> snapped = _snapToCatalog(sample, centers, candidates, k);
    if (cells == null) return snapped;
    return _reseed<PaletteEntry>(snapped, (e) => Lab.fromRgb(e.rgb), (want, current) {
      PaletteEntry? best;
      double bestD = double.infinity;
      for (final PaletteEntry e in candidates) {
        if (current.contains(e)) continue;
        final double d = deltaE2000(want, Lab.fromRgb(e.rgb));
        if (d < bestD) {
          bestD = d;
          best = e;
        }
      }
      return best;
    }, cells);
  }

  /// Цвета, не выигравшие ни одной клетки, заменяются: новый цвет берётся там, где клетка хуже всего покрыта палитрой.
  /// [fresh] возвращает замену для желаемого цвета или `null`, если подходящей нет (тогда цвет просто убирается).
  List<T> _reseed<T>(
    List<T> start,
    Lab Function(T) labOf,
    T? Function(Lab want, List<T> current) fresh,
    _CellMeans cells,
  ) {
    final List<T> palette = <T>[...start];
    for (int round = 0; round < 4 && palette.isNotEmpty; round++) {
      final List<Lab> labs = <Lab>[for (final T t in palette) labOf(t)];
      final List<int> wins = List<int>.filled(palette.length, 0);
      final Float64List error = Float64List(cells.count);
      for (int i = 0; i < cells.count; i++) {
        int best = 0;
        double bestD = double.infinity;
        for (int j = 0; j < labs.length; j++) {
          final double dl = cells.l[i] - labs[j].l;
          final double da = cells.a[i] - labs[j].a;
          final double db = cells.b[i] - labs[j].b;
          final double d = dl * dl + da * da + db * db;
          if (d < bestD) {
            bestD = d;
            best = j;
          }
        }
        wins[best]++;
        error[i] = math.sqrt(bestD) * cells.w[i];
      }
      final List<int> unused = <int>[
        for (int j = 0; j < palette.length; j++)
          if (wins[j] == 0) j,
      ];
      if (unused.isEmpty) break;
      final List<int> removed = <int>[];
      for (final int j in unused) {
        int worst = -1;
        for (int i = 0; i < cells.count; i++) {
          if (error[i] > _reseedMinError && (worst < 0 || error[i] > error[worst])) worst = i;
        }
        final T? replacement = worst < 0 ? null : fresh(Lab(cells.l[worst], cells.a[worst], cells.b[worst]), palette);
        if (replacement == null) {
          removed.add(j);
          continue;
        }
        palette[j] = replacement;
        final Lab added = labOf(replacement);
        for (int i = 0; i < cells.count; i++) {
          final double dl = cells.l[i] - added.l;
          final double da = cells.a[i] - added.a;
          final double db = cells.b[i] - added.b;
          error[i] = math.min(error[i], math.sqrt(dl * dl + da * da + db * db) * cells.w[i]);
        }
      }
      for (final int j in removed.reversed) {
        palette.removeAt(j);
      }
    }
    return palette;
  }

  /// Ошибка клетки (ΔE76), ниже которой новый цвет не заводим: разница не видна.
  static const double _reseedMinError = 4;

  /// Минимальная площадь группы в пикселях выборки: [accentMinCells] клеток по `scale²` рабочих пикселей.
  double _minGroup(_Sample s, int scale) => math.max(4, accentMinCells * scale * scale * s.count / s.pixels);

  // ---------------------------------------------------------------- выборка

  /// Потолок надбавки веса за контраст: на тёмном фоне со звёздами без него вся палитра уходит на блики.
  static const double _maxEdgeBoost = 3;

  static _Sample _takeSample(WorkImage work, int seed, int size) {
    final int n = work.width * work.height;
    final int target = math.min(n, size);
    final math.Random random = math.Random(seed * 7919 + 1);
    final Float64List l = Float64List(target);
    final Float64List a = Float64List(target);
    final Float64List b = Float64List(target);
    final Float64List w = Float64List(target);
    // Средняя сила краёв нужна для веса «контраст».
    double edgeSum = 0;
    final List<int> picked = <int>[];
    final List<double> edges = <double>[];
    for (int i = 0; i < target; i++) {
      final int p = math.min(n - 1, ((i + random.nextDouble()) * n / target).floor());
      if (work.alpha[p] < 0.5) continue;
      final double e = _edge(work, p);
      picked.add(p);
      edges.add(e);
      edgeSum += e;
    }
    final double meanEdge = picked.isEmpty ? 1 : edgeSum / picked.length;
    for (int i = 0; i < picked.length; i++) {
      final int p = picked[i];
      l[i] = work.lightness[p];
      a[i] = work.a[p];
      b[i] = work.b[p];
      w[i] = math.max(1e-6, work.importance[p]) * (1 + math.min(_maxEdgeBoost, edges[i] / (meanEdge + 1e-6)));
    }
    return _Sample(picked.length, l, a, b, w, work.width * work.height, work.scale);
  }

  /// Сила края в пикселе: разность Lab соседей по осям (как `edge_strength` прототипа).
  static double _edge(WorkImage work, int p) {
    final int w = work.width;
    final int h = work.height;
    final int x = p % w;
    final int y = p ~/ w;
    double axis(int from, int to) {
      final double dl = work.lightness[to] - work.lightness[from];
      final double da = work.a[to] - work.a[from];
      final double db = work.b[to] - work.b[from];
      return math.sqrt(dl * dl + da * da + db * db);
    }

    final double gx = (x > 0 && x < w - 1) ? axis(p - 1, p + 1) : 0;
    final double gy = (y > 0 && y < h - 1) ? axis(p - w, p + w) : 0;
    return math.sqrt(gx * gx + gy * gy);
  }

  // ---------------------------------------------------------------- k-means

  List<Lab> _kMeans(_Sample s, int k, math.Random random, double minGroup) {
    final int n = s.count;
    final List<int> seeds = <int>[];
    double total = 0;
    for (int i = 0; i < n; i++) {
      total += s.w[i];
    }
    int pickBy(List<double> mass, double sum) {
      double t = random.nextDouble() * sum;
      for (int i = 0; i < n; i++) {
        t -= mass[i];
        if (t <= 0) return i;
      }
      return n - 1;
    }

    final List<double> weights = <double>[for (int i = 0; i < n; i++) s.w[i]];
    seeds.add(pickBy(weights, total));
    final Float64List d2 = Float64List(n)..fillRange(0, n, double.infinity);
    while (seeds.length < k) {
      final int last = seeds.last;
      double sum = 0;
      final List<double> mass = List<double>.filled(n, 0);
      for (int i = 0; i < n; i++) {
        final double d = _dist2(s, i, s.l[last], s.a[last], s.b[last]);
        if (d < d2[i]) d2[i] = d;
        mass[i] = d2[i] * s.w[i];
        sum += mass[i];
      }
      if (sum <= 0) break;
      seeds.add(pickBy(mass, sum));
    }
    final int c = seeds.length;
    final Float64List cl = Float64List(c);
    final Float64List ca = Float64List(c);
    final Float64List cb = Float64List(c);
    for (int j = 0; j < c; j++) {
      cl[j] = s.l[seeds[j]];
      ca[j] = s.a[seeds[j]];
      cb[j] = s.b[seeds[j]];
    }
    final Int32List label = Int32List(n);
    for (int iteration = 0; iteration < iterations; iteration++) {
      bool changed = iteration == 0;
      for (int i = 0; i < n; i++) {
        int best = 0;
        double bestD = double.infinity;
        for (int j = 0; j < c; j++) {
          final double d = _dist2(s, i, cl[j], ca[j], cb[j]);
          if (d < bestD) {
            bestD = d;
            best = j;
          }
        }
        if (label[i] != best) {
          label[i] = best;
          changed = true;
        }
      }
      if (!changed) break;
      final Float64List sl = Float64List(c);
      final Float64List sa = Float64List(c);
      final Float64List sb = Float64List(c);
      final Float64List sw = Float64List(c);
      for (int i = 0; i < n; i++) {
        final int j = label[i];
        sl[j] += s.l[i] * s.w[i];
        sa[j] += s.a[i] * s.w[i];
        sb[j] += s.b[i] * s.w[i];
        sw[j] += s.w[i];
      }
      for (int j = 0; j < c; j++) {
        if (sw[j] > 0) {
          cl[j] = sl[j] / sw[j];
          ca[j] = sa[j] / sw[j];
          cb[j] = sb[j] / sw[j];
        }
      }
    }
    // Центры без точек и кластеры меньше [minGroup] (одиночные помехи, которые k-means++ любит выбирать первыми)
    // выбрасываем: место займут акценты, у которых площадь проверена. Самый большой кластер остаётся всегда.
    final List<int> sizes = List<int>.filled(c, 0);
    for (int i = 0; i < n; i++) {
      sizes[label[i]]++;
    }
    final int largest = sizes.indexOf(sizes.reduce(math.max));
    return <Lab>[
      for (int j = 0; j < c; j++)
        if (sizes[j] >= minGroup || j == largest) Lab(cl[j], ca[j], cb[j]),
    ];
  }

  static double _dist2(_Sample s, int i, double l, double a, double b) {
    final double dl = s.l[i] - l;
    final double da = s.a[i] - a;
    final double db = s.b[i] - b;
    return dl * dl + da * da + db * db;
  }

  // ---------------------------------------------------------------- акценты

  List<Lab> _addAccents(_Sample s, List<Lab> start, int total, double minGroup) {
    final List<Lab> centers = <Lab>[...start];
    if (centers.length >= total) return centers;
    final int n = s.count;
    final Float64List error = Float64List(n)..fillRange(0, n, double.infinity);
    void update(Lab c) {
      for (int i = 0; i < n; i++) {
        final double d = deltaE2000(Lab(s.l[i], s.a[i], s.b[i]), c);
        if (d < error[i]) error[i] = d;
      }
    }

    for (final Lab c in centers) {
      update(c);
    }
    while (centers.length < total) {
      final List<int> far = <int>[
        for (int i = 0; i < n; i++)
          if (error[i] > accentDeltaE) i,
      ];
      if (far.length < minGroup) break;
      far.sort((x, y) => error[y].compareTo(error[x]));
      Lab? found;
      // Самый далёкий пиксель может быть одиночной помехой: берём первого, вокруг которого набирается группа.
      for (final int candidate in far.take(40)) {
        final List<int> group = <int>[
          for (final int i in far)
            if (_dist2(s, i, s.l[candidate], s.a[candidate], s.b[candidate]) <= accentDeltaE * accentDeltaE) i,
        ];
        if (group.length < minGroup) continue;
        double sw = 0;
        double sl = 0;
        double sa = 0;
        double sb = 0;
        for (final int i in group) {
          sw += s.w[i];
          sl += s.l[i] * s.w[i];
          sa += s.a[i] * s.w[i];
          sb += s.b[i] * s.w[i];
        }
        found = Lab(sl / sw, sa / sw, sb / sw);
        break;
      }
      if (found == null) break;
      centers.add(found);
      update(found);
    }
    return centers;
  }

  // ---------------------------------------------------------------- каталог

  List<PaletteEntry> _snapToCatalog(_Sample s, List<Lab> centers, List<PaletteEntry> candidates, int wanted) {
    final List<Lab> catalog = <Lab>[for (final PaletteEntry e in candidates) Lab.fromRgb(e.rgb)];
    final int k = math.min(centers.length, catalog.length);
    final int target = math.min(wanted, catalog.length);

    // Каждому центру — ближайшая ещё не занятая позиция; первыми идут центры с очень близкой позицией.
    List<int> snap(List<Lab> wanted) {
      final List<List<double>> d = <List<double>>[
        for (final Lab c in wanted) <double>[for (final Lab p in catalog) deltaE2000(c, p)],
      ];
      final List<int> order = List<int>.generate(wanted.length, (i) => i)
        ..sort((x, y) {
          final double dx = d[x].reduce(math.min);
          final double dy = d[y].reduce(math.min);
          return dx != dy ? dx.compareTo(dy) : x.compareTo(y);
        });
      final Set<int> taken = <int>{};
      for (final int i in order) {
        if (taken.length >= k) break;
        int best = -1;
        for (int j = 0; j < catalog.length; j++) {
          if (taken.contains(j)) continue;
          if (best < 0 || d[i][j] < d[i][best]) best = j;
        }
        if (best >= 0) taken.add(best);
      }
      return taken.toList()..sort();
    }

    List<int> chosen = snap(centers.take(k).toList());
    for (int iteration = 0; iteration < medoidIterations; iteration++) {
      final int c = chosen.length;
      final Float64List sl = Float64List(c);
      final Float64List sa = Float64List(c);
      final Float64List sb = Float64List(c);
      final Float64List sw = Float64List(c);
      for (int i = 0; i < s.count; i++) {
        int best = 0;
        double bestD = double.infinity;
        for (int j = 0; j < c; j++) {
          final Lab p = catalog[chosen[j]];
          final double dd = _dist2(s, i, p.l, p.a, p.b);
          if (dd < bestD) {
            bestD = dd;
            best = j;
          }
        }
        sl[best] += s.l[i] * s.w[i];
        sa[best] += s.a[i] * s.w[i];
        sb[best] += s.b[i] * s.w[i];
        sw[best] += s.w[i];
      }
      final List<Lab> means = <Lab>[
        for (int j = 0; j < c; j++) sw[j] > 0 ? Lab(sl[j] / sw[j], sa[j] / sw[j], sb[j] / sw[j]) : catalog[chosen[j]],
      ];
      final List<int> next = snap(means);
      if (next.length == chosen.length && Set<int>.of(next).containsAll(chosen)) break;
      chosen = next;
    }
    // Центров могло быть меньше заданного (однотонные области): добираем позиции, которые хуже всего покрыты.
    while (chosen.length < target) {
      int worst = -1;
      double worstCost = 0;
      for (int i = 0; i < s.count; i++) {
        double nearest = double.infinity;
        for (final int j in chosen) {
          final Lab p = catalog[j];
          nearest = math.min(nearest, _dist2(s, i, p.l, p.a, p.b));
        }
        final double cost = nearest * s.w[i];
        if (cost > worstCost) {
          worstCost = cost;
          worst = i;
        }
      }
      final Lab want = worst < 0 ? catalog.first : Lab(s.l[worst], s.a[worst], s.b[worst]);
      int best = -1;
      double bestD = double.infinity;
      for (int j = 0; j < catalog.length; j++) {
        if (chosen.contains(j)) continue;
        final double d = deltaE2000(want, catalog[j]);
        if (d < bestD) {
          bestD = d;
          best = j;
        }
      }
      if (best < 0) break;
      chosen = <int>[...chosen, best]..sort();
    }
    return <PaletteEntry>[for (final int j in chosen) candidates[j]];
  }
}

final class _Sample {
  const _Sample(this.count, this.l, this.a, this.b, this.w, this.pixels, this.scale);

  final int count;
  final Float64List l;
  final Float64List a;
  final Float64List b;
  final Float64List w;

  /// Всего пикселей в рабочей картинке (для пересчёта площади в долю выборки).
  final int pixels;
  final int scale;
}

/// Средний цвет Lab каждой клетки (по непрозрачным пикселям) и вес важности: клетки для проверки палитры.
final class _CellMeans {
  const _CellMeans(this.count, this.l, this.a, this.b, this.w);

  factory _CellMeans.of(WorkImage work, CellRegions regions) {
    final int cells = regions.columns * regions.rows;
    final List<double> l = <double>[];
    final List<double> a = <double>[];
    final List<double> b = <double>[];
    final List<double> w = <double>[];
    for (int cell = 0; cell < cells; cell++) {
      double sl = 0;
      double sa = 0;
      double sb = 0;
      double sw = 0;
      int n = 0;
      for (int y = regions.top(cell); y < regions.bottom(cell); y++) {
        for (int x = regions.left(cell); x < regions.right(cell); x++) {
          final int p = y * work.width + x;
          if (work.alpha[p] < 0.5) continue;
          sl += work.lightness[p];
          sa += work.a[p];
          sb += work.b[p];
          sw += work.importance[p];
          n++;
        }
      }
      if (n == 0) continue;
      l.add(sl / n);
      a.add(sa / n);
      b.add(sb / n);
      w.add(sw / n);
    }
    return _CellMeans(
      l.length,
      Float64List.fromList(l),
      Float64List.fromList(a),
      Float64List.fromList(b),
      Float64List.fromList(w),
    );
  }

  final int count;
  final Float64List l;
  final Float64List a;
  final Float64List b;
  final Float64List w;
}
