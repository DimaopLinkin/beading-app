import 'package:beading/domain/stats/stats_range.dart';
import 'package:beading/presentation/stats/chart_buckets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime(2026, 11, 15, 22);

  test('неделя: семь столбиков по дням, пустые дни — ноль', () {
    final StatsRange range = StatsRange.of(StatsPeriod.week, now);
    final List<ChartBar> bars = chartBars(StatsPeriod.week, range, <DateTime, Duration>{
      DateTime(2026, 11, 10): const Duration(hours: 1),
    }, now);
    expect(bars, hasLength(7));
    expect(bars[1].time, const Duration(hours: 1));
    expect(bars[0].time, Duration.zero);
  });

  test('месяц: по числу дней месяца', () {
    expect(
      chartBars(StatsPeriod.month, StatsRange.of(StatsPeriod.month, now), const <DateTime, Duration>{}, now),
      hasLength(30),
    );
  });

  test('год: двенадцать месяцев, время суммируется по месяцам', () {
    final List<ChartBar> bars = chartBars(StatsPeriod.year, StatsRange.of(StatsPeriod.year, now), <DateTime, Duration>{
      DateTime(2026, 3): const Duration(hours: 1),
      DateTime(2026, 3, 20): const Duration(hours: 2),
    }, now);
    expect(bars, hasLength(12));
    expect(bars[2].time, const Duration(hours: 3));
  });

  test('всё время: с первого месяца работы до текущего; без работы пусто', () {
    final StatsRange all = StatsRange.all(now);
    expect(chartBars(StatsPeriod.all, all, const <DateTime, Duration>{}, now), isEmpty);
    final List<ChartBar> bars = chartBars(StatsPeriod.all, all, <DateTime, Duration>{
      DateTime(2026, 9, 5): const Duration(hours: 1),
    }, now);
    expect(bars.map((b) => b.start), <DateTime>[DateTime(2026, 9), DateTime(2026, 10), DateTime(2026, 11)]);
  });
}
