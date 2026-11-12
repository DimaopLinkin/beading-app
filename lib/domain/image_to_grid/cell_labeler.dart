import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/box_blur.dart';
import 'package:beading/domain/image_to_grid/cell_costs.dart';
import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:equatable/equatable.dart';

/// Результат разметки: номера цветов клеток (`1..`, `0` — пустая клетка) и цены всех цветов.
final class LabeledCells {
  const LabeledCells({required this.values, required this.costs, this.detail});

  final Uint16List values;
  final CellCosts costs;

  /// Доля заметных пикселей в каждой клетке (T64) или `null`, если разметчик заметность не считал: клетки с тонкой
  /// линией или бликом, которые очистка не должна стирать.
  final Float32List? detail;
}

/// Стадия 3 конвейера (ADR-0004): цена каждого цвета для каждой клетки и начальные номера.
abstract interface class CellLabeler {
  LabeledCells label({required WorkImage work, required CellRegions regions, required List<Lab> palette});
}

/// Цвет клетки голосованием пикселей: цена цвета — средняя Евклидова разница в Lab его до рабочих пикселей клетки,
/// клетка берёт цвет с минимальной ценой.
///
/// На границе двух областей 60/40 это цвет большей части, а не «грязная» смесь, которой нет в палитре.
///
/// Когда таблица «клетка × цвет» не помещается в [denseBudget] (T69), считаются точные цены только нескольких
/// цветов-кандидатов клетки, см. [CellCosts.sparse]; для небольших схем путь прежний, точный.
final class VotingCellLabeler extends Equatable implements CellLabeler {
  const VotingCellLabeler({this.denseBudget = CellCosts.denseBudget});

  /// Сколько чисел «клетка × цвет» считается плотно; больше — разреженная таблица.
  final int denseBudget;

  @override
  List<Object?> get props => <Object?>[denseBudget];

  /// Клетка с долей непрозрачности ниже этой пуста (как в CellSampler).
  static const double emptyBelowAlpha = 0.5;

  @override
  LabeledCells label({required WorkImage work, required CellRegions regions, required List<Lab> palette}) {
    final int cells = regions.columns * regions.rows;
    final int k = palette.length;
    final Uint16List values = Uint16List(cells);
    if (k == 0) {
      return LabeledCells(
        values: values,
        costs: CellCosts(columns: regions.columns, rows: regions.rows, colorCount: 0, values: Float32List(0)),
      );
    }
    if (cells * k > denseBudget) {
      return _labelSparse(work: work, regions: regions, palette: palette, denseBudget: denseBudget);
    }
    final Float64List pl = Float64List.fromList(<double>[for (final Lab c in palette) c.l]);
    final Float64List pa = Float64List.fromList(<double>[for (final Lab c in palette) c.a]);
    final Float64List pb = Float64List.fromList(<double>[for (final Lab c in palette) c.b]);
    final Float32List costs = Float32List(cells * k);
    final Float64List sum = Float64List(k);
    for (int cell = 0; cell < cells; cell++) {
      sum.fillRange(0, k, 0);
      double alphaSum = 0;
      int area = 0;
      int counted = 0;
      for (int y = regions.top(cell); y < regions.bottom(cell); y++) {
        for (int x = regions.left(cell); x < regions.right(cell); x++) {
          final int p = y * work.width + x;
          area++;
          alphaSum += work.alpha[p];
          if (work.alpha[p] < emptyBelowAlpha) continue;
          counted++;
          final double l = work.lightness[p];
          final double a = work.a[p];
          final double b = work.b[p];
          for (int c = 0; c < k; c++) {
            final double dl = l - pl[c];
            final double da = a - pa[c];
            final double db = b - pb[c];
            sum[c] += math.sqrt(dl * dl + da * da + db * db);
          }
        }
      }
      if (area == 0 || counted == 0 || alphaSum / area < emptyBelowAlpha) continue;
      int best = 0;
      for (int c = 0; c < k; c++) {
        final double cost = sum[c] / counted;
        costs[cell * k + c] = cost;
        if (cost < costs[cell * k + best]) best = c;
      }
      values[cell] = best + 1;
    }
    return LabeledCells(
      values: values,
      costs: CellCosts(columns: regions.columns, rows: regions.rows, colorCount: k, values: costs),
    );
  }
}

/// Голосование с весом заметности пикселя (T64; Weber и др., 2016): пиксель, чей цвет заметно отличается от среднего по
/// окрестности размером с клетку, весит больше, поэтому тонкая линия или блик внутри клетки не растворяются в фоне.
///
/// Вес `floor + min(cap, max(0, s − noise))`, где `s` — разница в Lab с окрестностью: до порога шума [noise] (после
/// сглаживания T52 это зерно, а не деталь) пиксели весят одинаково, сверху вес ограничен [cap], чтобы один яркий
/// пиксель не перетянул клетку. Заметными ([LabeledCells.detail]) считаются пиксели с `s` от [lineDeltaE].
final class DetailCellLabeler extends Equatable implements CellLabeler {
  const DetailCellLabeler({
    this.floor = 4,
    this.cap = 30,
    this.noise = 8,
    this.lineDeltaE = 30,
    this.denseBudget = CellCosts.denseBudget,
  });

  /// Сколько чисел «клетка × цвет» считается плотно; больше — разреженная таблица (T69), как у [VotingCellLabeler].
  final int denseBudget;

  final double floor;
  final double cap;
  final double noise;
  final double lineDeltaE;

  @override
  List<Object?> get props => <Object?>[floor, cap, noise, lineDeltaE, denseBudget];

  @override
  LabeledCells label({required WorkImage work, required CellRegions regions, required List<Lab> palette}) {
    final int w = work.width;
    final int h = work.height;
    final int r = math.max(1, work.scale);
    // Средняя окрестность считается с весом непрозрачности: прозрачные пиксели (Lab 0,0,0) не должны делать контур
    // вырезанного объекта «деталью».
    final Float32List alphaMean = boxBlur(work.alpha, w, h, r);
    Float32List weightedMean(Float32List channel) {
      final Float32List premultiplied = Float32List(channel.length);
      for (int i = 0; i < channel.length; i++) {
        premultiplied[i] = channel[i] * work.alpha[i];
      }
      final Float32List blurred = boxBlur(premultiplied, w, h, r);
      for (int i = 0; i < blurred.length; i++) {
        blurred[i] = alphaMean[i] > 1e-6 ? blurred[i] / alphaMean[i] : channel[i];
      }
      return blurred;
    }

    final Float32List ml = weightedMean(work.lightness);
    final Float32List ma = weightedMean(work.a);
    final Float32List mb = weightedMean(work.b);
    final int cells = regions.columns * regions.rows;
    final int k = palette.length;
    final Float32List detail = Float32List(cells);
    final Uint16List values = Uint16List(cells);
    if (k == 0) {
      return LabeledCells(
        values: values,
        costs: CellCosts(columns: regions.columns, rows: regions.rows, colorCount: 0, values: Float32List(0)),
        detail: detail,
      );
    }
    if (cells * k > denseBudget) {
      // Вес и «заметность» пикселя те же, что в плотном пути, только цены считаются у кандидатов клетки.
      final Float32List weights = Float32List(w * h);
      final Float32List salience = Float32List(w * h);
      for (int p = 0; p < w * h; p++) {
        final double dl = work.lightness[p] - ml[p];
        final double da = work.a[p] - ma[p];
        final double db = work.b[p] - mb[p];
        final double s = math.sqrt(dl * dl + da * da + db * db);
        salience[p] = s;
        weights[p] = floor + math.min(cap, math.max(0, s - noise));
      }
      return _labelSparse(
        work: work,
        regions: regions,
        palette: palette,
        denseBudget: denseBudget,
        weights: weights,
        salience: salience,
        lineDeltaE: lineDeltaE,
        detail: detail,
      );
    }
    final Float32List costs = Float32List(cells * k);
    final Float64List pl = Float64List.fromList(<double>[for (final Lab c in palette) c.l]);
    final Float64List pa = Float64List.fromList(<double>[for (final Lab c in palette) c.a]);
    final Float64List pb = Float64List.fromList(<double>[for (final Lab c in palette) c.b]);
    final Float64List sum = Float64List(k);
    for (int cell = 0; cell < cells; cell++) {
      sum.fillRange(0, k, 0);
      double total = 0;
      double alphaSum = 0;
      int area = 0;
      int counted = 0;
      int salient = 0;
      for (int y = regions.top(cell); y < regions.bottom(cell); y++) {
        for (int x = regions.left(cell); x < regions.right(cell); x++) {
          final int p = y * w + x;
          area++;
          alphaSum += work.alpha[p];
          if (work.alpha[p] < VotingCellLabeler.emptyBelowAlpha) continue;
          counted++;
          final double l = work.lightness[p];
          final double a = work.a[p];
          final double b = work.b[p];
          final double dl = l - ml[p];
          final double da = a - ma[p];
          final double db = b - mb[p];
          final double s = math.sqrt(dl * dl + da * da + db * db);
          if (s >= lineDeltaE) salient++;
          final double weight = floor + math.min(cap, math.max(0, s - noise));
          total += weight;
          for (int c = 0; c < k; c++) {
            final double el = l - pl[c];
            final double ea = a - pa[c];
            final double eb = b - pb[c];
            sum[c] += weight * math.sqrt(el * el + ea * ea + eb * eb);
          }
        }
      }
      if (area == 0 || counted == 0 || alphaSum / area < VotingCellLabeler.emptyBelowAlpha) continue;
      detail[cell] = salient / counted;
      int best = 0;
      for (int c = 0; c < k; c++) {
        final double cost = sum[c] / total;
        costs[cell * k + c] = cost;
        if (cost < costs[cell * k + best]) best = c;
      }
      values[cell] = best + 1;
    }
    return LabeledCells(
      values: values,
      costs: CellCosts(columns: regions.columns, rows: regions.rows, colorCount: k, values: costs),
      detail: detail,
    );
  }
}

/// Разметка для схем, чья плотная таблица цен не помещается в [denseBudget] (T69).
///
/// Для клетки: средний Lab и разброс (с теми же весами, что у цен), затем кандидаты — `K − 1` цветов палитры,
/// ближайших к среднему, и цвет, ближайший к самому далёкому от среднего пикселю (граница 60/40 всё же может взять цвет
/// большей части). Точные цены считаются только у кандидатов; цвет клетки — самый дешёвый из них.
///
/// [weights] — вес пикселя (без него 1), [salience] и [lineDeltaE] — подсчёт заметных пикселей в [detail].
LabeledCells _labelSparse({
  required WorkImage work,
  required CellRegions regions,
  required List<Lab> palette,
  required int denseBudget,
  Float32List? weights,
  Float32List? salience,
  double lineDeltaE = 0,
  Float32List? detail,
}) {
  final int cells = regions.columns * regions.rows;
  final int k = palette.length;
  final int slots = math.min(k, CellCosts.slotsFor(cells, budget: denseBudget));
  final Float64List pl = Float64List.fromList(<double>[for (final Lab c in palette) c.l]);
  final Float64List pa = Float64List.fromList(<double>[for (final Lab c in palette) c.a]);
  final Float64List pb = Float64List.fromList(<double>[for (final Lab c in palette) c.b]);
  final Uint16List values = Uint16List(cells);
  final Uint16List candidates = Uint16List(cells * slots);
  final Float32List candidateCosts = Float32List(cells * slots);
  final Uint8List counts = Uint8List(cells);
  final Float32List mean = Float32List(cells * 3);
  final Float32List spread = Float32List(cells)..fillRange(0, cells, -1);
  // Ближайшие к среднему цвета клетки, по возрастанию расстояния.
  final Int32List nearest = Int32List(slots);
  final Float64List nearestDistance = Float64List(slots);
  final int w = work.width;
  for (int cell = 0; cell < cells; cell++) {
    double alphaSum = 0;
    int area = 0;
    int counted = 0;
    double total = 0;
    double sl = 0;
    double sa = 0;
    double sb = 0;
    for (int y = regions.top(cell); y < regions.bottom(cell); y++) {
      for (int x = regions.left(cell); x < regions.right(cell); x++) {
        final int p = y * w + x;
        area++;
        alphaSum += work.alpha[p];
        if (work.alpha[p] < VotingCellLabeler.emptyBelowAlpha) continue;
        counted++;
        final double wt = weights == null ? 1 : weights[p];
        total += wt;
        sl += wt * work.lightness[p];
        sa += wt * work.a[p];
        sb += wt * work.b[p];
      }
    }
    if (area == 0 || counted == 0 || alphaSum / area < VotingCellLabeler.emptyBelowAlpha) continue;
    final double ml = sl / total;
    final double ma = sa / total;
    final double mb = sb / total;
    // Второй проход: разброс и самый далёкий от среднего пиксель.
    double spreadSum = 0;
    double farthest = -1;
    int farthestPixel = -1;
    int salient = 0;
    for (int y = regions.top(cell); y < regions.bottom(cell); y++) {
      for (int x = regions.left(cell); x < regions.right(cell); x++) {
        final int p = y * w + x;
        if (work.alpha[p] < VotingCellLabeler.emptyBelowAlpha) continue;
        final double dl = work.lightness[p] - ml;
        final double da = work.a[p] - ma;
        final double db = work.b[p] - mb;
        final double d = math.sqrt(dl * dl + da * da + db * db);
        spreadSum += (weights == null ? 1 : weights[p]) * d;
        if (d > farthest) {
          farthest = d;
          farthestPixel = p;
        }
        if (salience != null && salience[p] >= lineDeltaE) salient++;
      }
    }
    if (detail != null) detail[cell] = salient / counted;
    mean[cell * 3] = ml;
    mean[cell * 3 + 1] = ma;
    mean[cell * 3 + 2] = mb;
    spread[cell] = spreadSum / total;
    // Кандидаты: ближайшие к среднему (вставка в отсортированный короткий список).
    int found = 0;
    for (int c = 0; c < k; c++) {
      final double dl = ml - pl[c];
      final double da = ma - pa[c];
      final double db = mb - pb[c];
      final double d = dl * dl + da * da + db * db;
      if (found == slots && d >= nearestDistance[slots - 1]) continue;
      int at = found < slots ? found++ : slots - 1;
      while (at > 0 && nearestDistance[at - 1] > d) {
        nearest[at] = nearest[at - 1];
        nearestDistance[at] = nearestDistance[at - 1];
        at--;
      }
      nearest[at] = c;
      nearestDistance[at] = d;
    }
    final int base = cell * slots;
    for (int i = 0; i < slots - 1; i++) {
      candidates[base + i] = nearest[i];
    }
    // Цвет самого далёкого пикселя: если среди ближайших его нет — последний слот, иначе берём следующий по близости.
    int outlier = nearest[slots - 1];
    if (slots > 1 && farthestPixel >= 0) {
      final double l = work.lightness[farthestPixel];
      final double a = work.a[farthestPixel];
      final double b = work.b[farthestPixel];
      double bestD = double.infinity;
      for (int c = 0; c < k; c++) {
        final double dl = l - pl[c];
        final double da = a - pa[c];
        final double db = b - pb[c];
        final double d = dl * dl + da * da + db * db;
        if (d < bestD) {
          bestD = d;
          outlier = c;
        }
      }
      bool present = false;
      for (int i = 0; i < slots - 1; i++) {
        if (nearest[i] == outlier) present = true;
      }
      if (present) outlier = nearest[slots - 1];
    }
    candidates[base + slots - 1] = outlier;
    counts[cell] = slots;
    // Точные цены кандидатов.
    for (int y = regions.top(cell); y < regions.bottom(cell); y++) {
      for (int x = regions.left(cell); x < regions.right(cell); x++) {
        final int p = y * w + x;
        if (work.alpha[p] < VotingCellLabeler.emptyBelowAlpha) continue;
        final double wt = weights == null ? 1 : weights[p];
        final double l = work.lightness[p];
        final double a = work.a[p];
        final double b = work.b[p];
        for (int i = 0; i < slots; i++) {
          final int c = candidates[base + i];
          final double el = l - pl[c];
          final double ea = a - pa[c];
          final double eb = b - pb[c];
          candidateCosts[base + i] += wt * math.sqrt(el * el + ea * ea + eb * eb);
        }
      }
    }
    int best = candidates[base];
    double bestCost = double.infinity;
    for (int i = 0; i < slots; i++) {
      final double cost = candidateCosts[base + i] / total;
      candidateCosts[base + i] = cost;
      final int c = candidates[base + i];
      if (cost < bestCost || (cost == bestCost && c < best)) {
        bestCost = cost;
        best = c;
      }
    }
    values[cell] = best + 1;
  }
  return LabeledCells(
    values: values,
    costs: CellCosts.sparse(
      columns: regions.columns,
      rows: regions.rows,
      colorCount: k,
      slots: slots,
      candidates: candidates,
      candidateCosts: candidateCosts,
      candidateCounts: counts,
      mean: mean,
      spread: spread,
      palette: palette,
    ),
    detail: detail,
  );
}
