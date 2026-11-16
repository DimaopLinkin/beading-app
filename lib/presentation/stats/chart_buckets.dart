import 'package:beading/domain/stats/stats_range.dart';
import 'package:equatable/equatable.dart';

/// Один столбик графика: день или месяц. [start] — полночь дня или первое число месяца.
final class ChartBar extends Equatable {
  const ChartBar({required this.start, required this.time});

  final DateTime start;
  final Duration time;

  @override
  List<Object?> get props => <Object?>[start, time];
}

/// Столбики графика за период: неделя и месяц по дням, год и всё время по месяцам (без пустого хвоста в будущем).
List<ChartBar> chartBars(StatsPeriod period, StatsRange range, Map<DateTime, Duration> perDay, DateTime now) {
  switch (period) {
    case StatsPeriod.week:
    case StatsPeriod.month:
      final List<ChartBar> bars = <ChartBar>[];
      for (DateTime d = range.start; d.isBefore(range.end); d = DateTime(d.year, d.month, d.day + 1)) {
        bars.add(ChartBar(start: d, time: perDay[d] ?? Duration.zero));
      }
      return bars;
    case StatsPeriod.year:
      return _months(range.start, range.end, perDay);
    case StatsPeriod.all:
      if (perDay.isEmpty) {
        return const <ChartBar>[];
      }
      final DateTime first = (perDay.keys.toList()..sort()).first;
      return _months(DateTime(first.year, first.month), range.end, perDay);
  }
}

List<ChartBar> _months(DateTime from, DateTime to, Map<DateTime, Duration> perDay) {
  final List<ChartBar> bars = <ChartBar>[];
  for (DateTime m = from; m.isBefore(to); m = DateTime(m.year, m.month + 1)) {
    Duration sum = Duration.zero;
    for (final MapEntry<DateTime, Duration> e in perDay.entries) {
      if (e.key.year == m.year && e.key.month == m.month) {
        sum += e.value;
      }
    }
    bars.add(ChartBar(start: m, time: sum));
  }
  return bars;
}
