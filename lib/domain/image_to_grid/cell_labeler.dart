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
final class VotingCellLabeler extends Equatable implements CellLabeler {
  const VotingCellLabeler();

  @override
  List<Object?> get props => const <Object?>[];

  /// Клетка с долей непрозрачности ниже этой пуста (как в CellSampler).
  static const double emptyBelowAlpha = 0.5;

  @override
  LabeledCells label({required WorkImage work, required CellRegions regions, required List<Lab> palette}) {
    final int cells = regions.columns * regions.rows;
    final int k = palette.length;
    final Float32List costs = Float32List(cells * k);
    final Uint16List values = Uint16List(cells);
    if (k == 0) {
      return LabeledCells(
        values: values,
        costs: CellCosts(columns: regions.columns, rows: regions.rows, colorCount: 0, values: costs),
      );
    }
    final Float64List pl = Float64List.fromList(<double>[for (final Lab c in palette) c.l]);
    final Float64List pa = Float64List.fromList(<double>[for (final Lab c in palette) c.a]);
    final Float64List pb = Float64List.fromList(<double>[for (final Lab c in palette) c.b]);
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
  const DetailCellLabeler({this.floor = 4, this.cap = 30, this.noise = 8, this.lineDeltaE = 30});

  final double floor;
  final double cap;
  final double noise;
  final double lineDeltaE;

  @override
  List<Object?> get props => <Object?>[floor, cap, noise, lineDeltaE];

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
    final Float32List costs = Float32List(cells * k);
    final Float32List detail = Float32List(cells);
    final Uint16List values = Uint16List(cells);
    if (k == 0) {
      return LabeledCells(
        values: values,
        costs: CellCosts(columns: regions.columns, rows: regions.rows, colorCount: 0, values: costs),
        detail: detail,
      );
    }
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
