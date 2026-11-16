import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';

/// Смешанная техника (T72): полукрест другой нитки поверх полного креста.
///
/// В вышивках так делают плавные переходы без новых цветов: сверху полного креста цвета A кладут один стежок `/`
/// цвета B, и издали клетка выглядит как смесь двух ниток. Цвет клетки в модели — [mixWeight] ниток B и остальное A
/// (линейный RGB): верхний стежок закрывает меньше половины креста.
///
/// Для каждой закрашенной клетки пробуются цвета B только из **соседних** клеток (переход идёт между соседями, и новых
/// ниток не появляется). Смесь годится, если она ближе к цвету клетки на фото, чем сама A, минимум на [minGain] (ΔE2000).
/// Дальше убирается «конфетти»: полукрест остаётся, только если ещё минимум [minNeighbors] соседей из восьми получили
/// полукрест того же цвета; всего не больше [maxShare] закрашенных клеток (по убыванию выигрыша), после чего
/// проверка соседей повторяется.
///
/// Клетки с блендом (две нитки в игле) не участвуют ни как A, ни как B: полукрест из бленда поверх креста — «грязный»
/// цвет, которого бленды как раз избегают. Клетки вне [subject] и клетки из [skip] пропускаются.
///
/// Чистая функция без случайности. Возвращает полукресты `/` (`PartialKind.half`), цвет — номер записи палитры с единицы.
List<PartialStitch> suggestOverlays(
  GeneratedPattern pattern,
  List<Rgb?> cellColors, {
  Uint8List? subject,
  Set<int> skip = const <int>{},
  double mixWeight = 0.3,
  double minGain = 2.5,
  int minNeighbors = 2,
  double maxShare = 0.2,
  double maxPairDeltaE = 30,
}) {
  final int columns = pattern.grid.width;
  final int rows = pattern.grid.height;
  final int total = columns * rows;
  if (cellColors.length != total || pattern.palette.length < 2) return const <PartialStitch>[];
  final List<Lab> palette = <Lab>[for (final e in pattern.palette) Lab.fromRgb(e.rgb)];
  final List<bool> plain = <bool>[for (final e in pattern.palette) e.blendPartner == null];
  // Смесь A (две доли) и B (одна доля) даёт 1/3 B; для другого веса берём ближайшее целое отношение долей.
  final int shareB = math.max(1, (mixWeight * 10).round());
  final Map<int, Lab> mixes = <int, Lab>{};
  Lab mixOf(int a, int b) => mixes.putIfAbsent(a * palette.length + b, () {
    return Lab.fromRgb(
      Rgb.average(<Rgb>[
        for (int i = 0; i < 10 - shareB; i++) pattern.palette[a].rgb,
        for (int i = 0; i < shareB; i++) pattern.palette[b].rgb,
      ]),
    );
  });

  double d76(Lab p, Lab q) {
    final double dl = p.l - q.l;
    final double da = p.a - q.a;
    final double db = p.b - q.b;
    return math.sqrt(dl * dl + da * da + db * db);
  }

  final List<int> best = List<int>.filled(total, -1);
  final List<double> gain = List<double>.filled(total, 0);
  int filled = 0;
  for (int cell = 0; cell < total; cell++) {
    final int value = pattern.grid.cells[cell];
    if (value == 0) continue;
    filled++;
    final Rgb? color = cellColors[cell];
    final int a = value - 1;
    if (color == null || !plain[a] || skip.contains(cell) || (subject != null && subject[cell] == 0)) continue;
    final Lab target = Lab.fromRgb(color);
    final double current = d76(target, palette[a]);
    if (current < 4) continue;
    final double currentDe = deltaE2000(target, palette[a]);
    final int x = cell % columns;
    final int y = cell ~/ columns;
    final Set<int> tried = <int>{};
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final int nx = x + dx;
        final int ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= columns || ny >= rows) continue;
        final int nv = pattern.grid.cells[ny * columns + nx];
        final int b = nv - 1;
        if (nv == 0 || b == a || !plain[b] || !tried.add(b)) continue;
        if (d76(palette[a], palette[b]) > maxPairDeltaE) continue;
        final Lab mix = mixOf(a, b);
        if (d76(target, mix) >= current) continue;
        final double g = currentDe - deltaE2000(target, mix);
        if (g >= minGain && g > gain[cell]) {
          gain[cell] = g;
          best[cell] = b;
        }
      }
    }
  }

  int neighborsWithSame(int cell, List<int> choice) {
    final int x = cell % columns;
    final int y = cell ~/ columns;
    int count = 0;
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final int nx = x + dx;
        final int ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= columns || ny >= rows) continue;
        if (choice[ny * columns + nx] == choice[cell]) count++;
      }
    }
    return count;
  }

  List<int> coherent(List<int> choice) => <int>[
    for (int cell = 0; cell < total; cell++)
      if (choice[cell] >= 0 && neighborsWithSame(cell, choice) >= minNeighbors) choice[cell] else -1,
  ];

  List<int> kept = coherent(best);
  final int limit = (filled * maxShare).floor();
  final List<int> chosen = <int>[
    for (int cell = 0; cell < total; cell++)
      if (kept[cell] >= 0) cell,
  ];
  if (chosen.length > limit) {
    chosen.sort((p, q) => gain[q] != gain[p] ? gain[q].compareTo(gain[p]) : p.compareTo(q));
    final Set<int> top = chosen.take(limit).toSet();
    kept = coherent(<int>[
      for (int cell = 0; cell < total; cell++)
        if (top.contains(cell)) kept[cell] else -1,
    ]);
  }
  return <PartialStitch>[
    for (int cell = 0; cell < total; cell++)
      if (kept[cell] >= 0)
        PartialStitch(
          column: cell % columns,
          row: cell ~/ columns,
          kind: PartialKind.half,
          orientation: StitchOrientation.slash,
          color: kept[cell] + 1,
        ),
  ];
}
