import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:equatable/equatable.dart';

/// Предложение бленда для вышивки (T57): две нитки палитры в одной игле дают цвет, который для [cells] ближе к цвету
/// фото, чем любой одиночный цвет палитры.
///
/// Предложение не меняет схему: решение принимает пользовательница (T46/T49 превращают пару в `PatternColor.blend`
/// с каталожными нитками выбранного бренда и перекрашивают [cells]).
final class BlendSuggestion extends Equatable {
  BlendSuggestion({
    required this.first,
    required this.second,
    required this.rgb,
    required List<int> cells,
    required this.meanGain,
  }) : cells = List<int>.unmodifiable(cells);

  /// Номера цветов в `GeneratedPattern.palette` (с нуля), `first < second`.
  final int first;
  final int second;

  /// Цвет бленда: среднее двух ниток в линейном RGB, как у `PatternColor.blend`.
  final Rgb rgb;

  /// Клетки (ряд × столбцов + столбец), для которых бленд лучше всех одиночных цветов палитры.
  final List<int> cells;

  /// На сколько в среднем падает ΔE2000 по этим клеткам, если взять бленд.
  final double meanGain;

  @override
  List<Object?> get props => <Object?>[first, second, rgb, cells, meanGain];
}

/// Ищет бленды для [pattern]: [cellColors] — цвета клеток после ресэмплинга (по рядам, слева направо).
///
/// Пара из цветов палитры годится, если расстояние между ними на плоскости цвета Δab = hypot(Δa, Δb) не больше
/// [maxPairChroma] (дальний по оттенку бленд — «грязный» цвет, а не переход) и разница светлоты |ΔL| не больше
/// [maxPairLightness] (тёмная нитка может встать в пару со светлой того же оттенка, например чёрная и тёмно-синяя:
/// так закрываются пробелы каталога в тёмных тонах). Пары ближе 3 ΔE76 пропускаются: смешивать почти одинаковое
/// незачем. Клетка идёт в бленд, если он ближе к ней, чем лучший одиночный цвет, минимум на [margin] (ΔE76).
/// Предложение держится, если в нём не меньше [minCells] клеток и средний выигрыш не меньше [minGain] ΔE2000. Каждая
/// клетка достаётся одному предложению (сначала самому выгодному); всего не больше [maxSuggestions], а если он не
/// задан, то `max(4, число цветов палитры ~/ 4)`: на большой палитре пробелов больше.
List<BlendSuggestion> suggestBlends(
  GeneratedPattern pattern,
  List<Rgb?> cellColors, {
  int? maxSuggestions,
  int minCells = 6,
  double maxPairChroma = 30,
  double maxPairLightness = 40,
  double margin = 1.5,
  double minGain = 2,
}) {
  final int count = pattern.palette.length;
  final int limit = maxSuggestions ?? math.max(4, count ~/ 4);
  if (count < 2 || cellColors.length != pattern.grid.width * pattern.grid.height) return const <BlendSuggestion>[];
  final List<Lab> palette = <Lab>[for (final e in pattern.palette) Lab.fromRgb(e.rgb)];
  final List<(int, int, Rgb, Lab)> pairs = <(int, int, Rgb, Lab)>[];
  for (int i = 0; i < count; i++) {
    for (int j = i + 1; j < count; j++) {
      final double d = _distance(palette[i], palette[j]);
      final double chroma = math.sqrt(
        math.pow(palette[i].a - palette[j].a, 2) + math.pow(palette[i].b - palette[j].b, 2),
      );
      if (d < 3 || chroma > maxPairChroma || (palette[i].l - palette[j].l).abs() > maxPairLightness) continue;
      final Rgb mix = Rgb.average(<Rgb>[pattern.palette[i].rgb, pattern.palette[j].rgb]);
      pairs.add((i, j, mix, Lab.fromRgb(mix)));
    }
  }
  if (pairs.isEmpty) return const <BlendSuggestion>[];

  // Для каждой клетки: цвет и ΔE76 до лучшего одиночного цвета.
  final List<Lab?> targets = <Lab?>[for (final Rgb? c in cellColors) c == null ? null : Lab.fromRgb(c)];
  final List<double> single = List<double>.filled(targets.length, 0);
  final List<double> singleDe = List<double>.filled(targets.length, 0);
  for (int cell = 0; cell < targets.length; cell++) {
    final Lab? target = targets[cell];
    if (target == null || pattern.grid.cells[cell] == 0) continue;
    double best = double.infinity;
    int bestIndex = 0;
    for (int c = 0; c < count; c++) {
      final double d = _distance(target, palette[c]);
      if (d < best) {
        best = d;
        bestIndex = c;
      }
    }
    single[cell] = best;
    singleDe[cell] = deltaE2000(target, palette[bestIndex]);
  }

  // Кандидаты пары: клетка и выигрыш по ΔE2000. Пара годится клетке, только если её цвет ближе лучшего одиночного
  // минимум на margin: цвета пар разложены по кубикам Lab, и клетка смотрит лишь кубики в этом радиусе (T70, без этого
  // вышивка в миллион клеток и 120 цветов считала бленды минуту). Клетки идут по возрастанию, как раньше, поэтому
  // клетки каждой пары лежат в буфере по возрастанию (T99: типизированные буферы вместо карт, на большой схеме
  // кандидатов десятки миллионов).
  final List<_Candidates> candidates = <_Candidates>[for (int p = 0; p < pairs.length; p++) _Candidates()];
  final _MixGrid grid = _MixGrid(<Lab>[for (final (int, int, Rgb, Lab) pair in pairs) pair.$4]);
  for (int cell = 0; cell < targets.length; cell++) {
    final Lab? target = targets[cell];
    // Клетка, уже совпавшая с цветом палитры, в бленде не нуждается.
    if (target == null || single[cell] <= margin + 1) continue;
    grid.near(target, single[cell] - margin, (p) {
      final Lab mix = pairs[p].$4;
      if (_distance(target, mix) + margin >= single[cell]) return;
      final double gain = singleDe[cell] - deltaE2000(target, mix);
      if (gain > 0) candidates[p].add(cell, gain);
    });
  }

  // Жадный отбор: каждый раз берётся пара с наибольшим суммарным выигрышем по ещё не занятым клеткам. Суммарный
  // выигрыш пары только падает (занятые клетки выбывают), поэтому последний посчитанный итог — верхняя граница, и
  // заново считать нужно лишь пары, чья граница не ниже лучшего найденного итога. Выбор тот же, что при полном
  // переборе: итоги считаются теми же суммами в том же порядке, а при равенстве побеждает пара с меньшим номером.
  final Uint8List taken = Uint8List(targets.length);
  final List<double> bound = <double>[for (final _Candidates c in candidates) c.total(taken).total];
  final List<BlendSuggestion> out = <BlendSuggestion>[];
  final Uint8List used = Uint8List(pairs.length);
  final List<int> order = List<int>.generate(pairs.length, (p) => p);
  while (out.length < limit) {
    order.sort((x, y) {
      final int byBound = bound[y].compareTo(bound[x]);
      return byBound != 0 ? byBound : x - y;
    });
    int bestPair = -1;
    double bestTotal = 0;
    for (final int p in order) {
      if (used[p] == 1) continue;
      // Дальше границы только ниже: лучше уже не найти (при равной границе пара с большим номером не побеждает).
      if (bound[p] < bestTotal || (bound[p] == bestTotal && bestPair >= 0 && p > bestPair)) {
        if (bound[p] < bestTotal) break;
        continue;
      }
      final ({double total, int cells}) now = candidates[p].total(taken);
      bound[p] = now.total;
      if (now.cells < minCells || now.total / now.cells < minGain) continue;
      if (now.total > bestTotal || (now.total == bestTotal && bestPair >= 0 && p < bestPair)) {
        bestTotal = now.total;
        bestPair = p;
      }
    }
    if (bestPair < 0) break;
    used[bestPair] = 1;
    final _Candidates chosen = candidates[bestPair];
    final List<int> cells = <int>[];
    double gainSum = 0;
    for (int i = 0; i < chosen.length; i++) {
      final int cell = chosen.cells[i];
      if (taken[cell] == 1) continue;
      cells.add(cell);
      gainSum += chosen.gains[i];
    }
    for (final int cell in cells) {
      taken[cell] = 1;
    }
    final (int first, int second, Rgb mix, Lab _) = pairs[bestPair];
    out.add(BlendSuggestion(first: first, second: second, rgb: mix, cells: cells, meanGain: gainSum / cells.length));
  }
  return out;
}

/// Клетки пары и выигрыш по каждой, по возрастанию клетки; буферы растут вдвое.
final class _Candidates {
  Int32List cells = Int32List(16);
  Float64List gains = Float64List(16);
  int length = 0;

  void add(int cell, double gain) {
    if (length == cells.length) {
      cells = Int32List(length * 2)..setRange(0, length, cells);
      gains = Float64List(length * 2)..setRange(0, length, gains);
    }
    cells[length] = cell;
    gains[length] = gain;
    length++;
  }

  /// Сумма выигрыша и число клеток, ещё не занятых другим предложением (отмечены в [taken]).
  ({double total, int cells}) total(Uint8List taken) {
    double sum = 0;
    int count = 0;
    for (int i = 0; i < length; i++) {
      if (taken[cells[i]] == 1) continue;
      sum += gains[i];
      count++;
    }
    return (total: sum, cells: count);
  }
}

/// Цвета пар, разложенные по кубикам Lab со стороной [_side]: поиск всех цветов не дальше радиуса без перебора.
final class _MixGrid {
  _MixGrid(List<Lab> mixes) {
    double minL = double.infinity, minA = double.infinity, minB = double.infinity;
    double maxL = -double.infinity, maxA = -double.infinity, maxB = -double.infinity;
    for (final Lab m in mixes) {
      minL = math.min(minL, m.l);
      minA = math.min(minA, m.a);
      minB = math.min(minB, m.b);
      maxL = math.max(maxL, m.l);
      maxA = math.max(maxA, m.a);
      maxB = math.max(maxB, m.b);
    }
    _origin = Lab(minL, minA, minB);
    _nl = (maxL - minL) ~/ _side + 1;
    _na = (maxA - minA) ~/ _side + 1;
    _nb = (maxB - minB) ~/ _side + 1;
    _buckets = List<List<int>?>.filled(_nl * _na * _nb, null);
    for (int p = 0; p < mixes.length; p++) {
      final Lab m = mixes[p];
      final int index = (((m.l - minL) ~/ _side) * _na + (m.a - minA) ~/ _side) * _nb + (m.b - minB) ~/ _side;
      (_buckets[index] ??= <int>[]).add(p);
    }
  }

  static const double _side = 6;
  late final Lab _origin;
  late final int _nl;
  late final int _na;
  late final int _nb;
  late final List<List<int>?> _buckets;

  /// Вызывает [visit] для каждой пары из кубиков, задетых шаром радиуса [radius] вокруг [center] (и, возможно,
  /// нескольких пар чуть дальше: точную проверку делает вызывающий).
  void near(Lab center, double radius, void Function(int pair) visit) {
    if (radius <= 0) return;
    final (int, int) l = _range(center.l - _origin.l, radius, _nl);
    final (int, int) a = _range(center.a - _origin.a, radius, _na);
    final (int, int) b = _range(center.b - _origin.b, radius, _nb);
    for (int i = l.$1; i <= l.$2; i++) {
      for (int j = a.$1; j <= a.$2; j++) {
        for (int k = b.$1; k <= b.$2; k++) {
          final List<int>? bucket = _buckets[(i * _na + j) * _nb + k];
          if (bucket == null) continue;
          for (final int p in bucket) {
            visit(p);
          }
        }
      }
    }
  }

  static (int, int) _range(double offset, double radius, int count) {
    final int low = math.max(0, ((offset - radius) / _side).floor());
    final int high = math.min(count - 1, ((offset + radius) / _side).floor());
    return (low, high);
  }
}

double _distance(Lab x, Lab y) {
  final double dl = x.l - y.l;
  final double da = x.a - y.a;
  final double db = x.b - y.b;
  return math.sqrt(dl * dl + da * da + db * db);
}
