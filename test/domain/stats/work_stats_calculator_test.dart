import 'package:beading/domain/stats/stats_range.dart';
import 'package:beading/domain/stats/work_stats.dart';
import 'package:beading/domain/stats/work_stats_calculator.dart';
import 'package:beading/domain/weaving/work_session.dart';
import 'package:flutter_test/flutter_test.dart';

WorkSession s(String project, DateTime start, Duration length, {String id = 'x'}) =>
    WorkSession(id: id, projectId: project, startedAt: start.toUtc(), endedAt: start.add(length).toUtc());

void main() {
  final DateTime now = DateTime(2026, 11, 15, 22); // воскресенье
  const WorkStatsCalculator calc = WorkStatsCalculator();
  final StatsRange all = StatsRange.all(now);

  test('пустой список даёт нули', () {
    final WorkStats r = calc.compute(const <WorkSession>[], all, now);
    expect(r.total, Duration.zero);
    expect(r.daysWithWork, 0);
    expect(r.averagePerWorkDay, Duration.zero);
    expect(r.longestSession, Duration.zero);
    expect(r.perDay, isEmpty);
  });

  test('суммирует время, дни, среднее и самую долгую сессию', () {
    final List<WorkSession> sessions = <WorkSession>[
      s('a', DateTime(2026, 11, 10, 9), const Duration(hours: 1), id: '1'),
      s('a', DateTime(2026, 11, 10, 20), const Duration(minutes: 30), id: '2'),
      s('b', DateTime(2026, 11, 12, 9), const Duration(hours: 2), id: '3'),
    ];
    final WorkStats r = calc.compute(sessions, all, now);
    expect(r.total, const Duration(hours: 3, minutes: 30));
    expect(r.daysWithWork, 2);
    expect(r.averagePerWorkDay, const Duration(hours: 1, minutes: 45));
    expect(r.longestSession, const Duration(hours: 2));
    expect(r.perDay[DateTime(2026, 11, 10)], const Duration(hours: 1, minutes: 30));
  });

  test('сессия через полночь делится по местным дням', () {
    final WorkStats r = calc.compute(
      <WorkSession>[s('a', DateTime(2026, 11, 10, 23), const Duration(hours: 2))],
      all,
      now,
    );
    expect(r.perDay[DateTime(2026, 11, 10)], const Duration(hours: 1));
    expect(r.perDay[DateTime(2026, 11, 11)], const Duration(hours: 1));
    expect(r.daysWithWork, 2);
    expect(r.longestSession, const Duration(hours: 2));
  });

  test('пересечения (два устройства) не считаются дважды, и между проектами тоже', () {
    final WorkStats r = calc.compute(
      <WorkSession>[
        s('a', DateTime(2026, 11, 10, 9), const Duration(hours: 1), id: '1'),
        s('b', DateTime(2026, 11, 10, 9, 30), const Duration(hours: 1), id: '2'),
      ],
      all,
      now,
    );
    expect(r.total, const Duration(hours: 1, minutes: 30));
  });

  test('конец сессии обрезается по «сейчас», аномально длинная — по пределу', () {
    final WorkStats future = calc.compute(
      <WorkSession>[s('a', DateTime(2026, 11, 15, 21), const Duration(hours: 5))],
      all,
      now,
    );
    expect(future.total, const Duration(hours: 1));
    final WorkStats huge = calc.compute(
      <WorkSession>[s('a', DateTime(2026, 11, 1, 1), const Duration(hours: 40))],
      all,
      now,
    );
    expect(huge.total, const Duration(hours: 12));
  });

  test('сессия без конца — ноль', () {
    final WorkStats r = calc.compute(
      <WorkSession>[WorkSession(id: 'x', projectId: 'a', startedAt: DateTime(2026, 11, 10, 9).toUtc())],
      all,
      now,
    );
    expect(r.total, Duration.zero);
    expect(r.daysWithWork, 0);
  });

  test('неделя начинается с понедельника, offset листает назад', () {
    final StatsRange week = StatsRange.of(StatsPeriod.week, now);
    expect(week.start, DateTime(2026, 11, 9));
    expect(week.end, DateTime(2026, 11, 16));
    final StatsRange prev = StatsRange.of(StatsPeriod.week, now, offset: -1);
    expect(prev.start, DateTime(2026, 11, 2));
    final StatsRange month = StatsRange.of(StatsPeriod.month, now);
    expect(month.start, DateTime(2026, 11));
    expect(month.end, DateTime(2026, 12));
    final StatsRange year = StatsRange.of(StatsPeriod.year, now, offset: -1);
    expect(year.start, DateTime(2025));
    expect(year.end, DateTime(2026));
  });

  test('в период попадает только время внутри него', () {
    final StatsRange week = StatsRange.of(StatsPeriod.week, now);
    final WorkStats r = calc.compute(
      <WorkSession>[
        s('a', DateTime(2026, 11, 8, 23), const Duration(hours: 2), id: '1'),
        s('a', DateTime(2026, 11, 3, 9), const Duration(hours: 1), id: '2'),
      ],
      week,
      now,
    );
    expect(r.total, const Duration(hours: 1));
    expect(r.longestSession, const Duration(hours: 1));
  });

  test('по проектам: время каждого проекта за период', () {
    final Map<String, Duration> by = calc.byProject(
      <WorkSession>[
        s('a', DateTime(2026, 11, 10, 9), const Duration(hours: 1), id: '1'),
        s('b', DateTime(2026, 11, 10, 11), const Duration(minutes: 20), id: '2'),
        s('a', DateTime(2026, 11, 11, 9), const Duration(hours: 1), id: '3'),
      ],
      all,
      now,
    );
    expect(by['a'], const Duration(hours: 2));
    expect(by['b'], const Duration(minutes: 20));
  });
}
