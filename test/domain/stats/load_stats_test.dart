import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/stats/load_project_stats.dart';
import 'package:beading/domain/stats/load_stats_overview.dart';
import 'package:beading/domain/stats/project_progress.dart';
import 'package:beading/domain/stats/project_stats.dart';
import 'package:beading/domain/stats/stats_overview.dart';
import 'package:beading/domain/stats/stats_range.dart';
import 'package:beading/domain/weaving/work_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_work_sessions.dart';

Project _project(String id, Craft craft, {ProjectStatus status = ProjectStatus.inProgress, ContentKind? kind}) =>
    Project(
      id: id,
      name: id,
      status: status,
      craft: craft,
      technique: Technique.defaultFor(craft),
      contentKind: kind ?? ContentKind.grid,
      notes: '',
      coverPath: null,
      lastWorkedAt: DateTime.utc(2026),
    );

void main() {
  late FakeProjectRepository projects;
  late FakeWorkSessionRepository sessions;
  late FakeGridPatternRepository patterns;
  late FakeGridProgressStore rows;
  late FakeCellProgressStore cells;
  late FakeClock clock;
  late ProjectProgressReader reader;

  setUp(() {
    projects = FakeProjectRepository();
    sessions = FakeWorkSessionRepository();
    patterns = FakeGridPatternRepository();
    rows = FakeGridProgressStore();
    cells = FakeCellProgressStore();
    clock = FakeClock(DateTime(2026, 11, 15, 22));
    reader = ProjectProgressReader(patterns: patterns, rows: rows, cells: cells);
  });

  Future<void> work(String project, DateTime start, Duration length) async {
    final WorkSession s = (await sessions.start(project, start)).valueOrNull!;
    await sessions.touch(s.id, start.add(length));
  }

  test('прогресс вышивки — крестики, бисера — бусины в отмеченных рядах и сами ряды', () async {
    patterns.byProject['x'] = sampleGridPattern(projectId: 'x');
    patterns.byProject['b'] = sampleGridPattern(projectId: 'b');
    await cells.setCells('pat-1', const <CellPosition>[CellPosition(0, 0), CellPosition(1, 0)], done: true);
    rows.rows.add(0);
    final ProjectProgress x = (await reader.read(_project('x', Craft.crossStitch)))!;
    expect((x.done, x.total, x.remaining, x.percent), (2, 9, 7, 22));
    expect(x.rowsDone, isNull);
    final ProjectProgress b = (await reader.read(_project('b', Craft.beading)))!;
    expect(b.total, 9);
    expect(b.rowsTotal, 4);
    expect(b.rowsDone, 1);
    expect(b.done, greaterThan(0));
    expect(await reader.read(_project('n', Craft.beading, kind: ContentKind.steps)), isNull);
    expect(await reader.read(_project('missing', Craft.beading)), isNull);
  });

  test('статистика проекта: время, сессии, дни, прогресс и темп', () async {
    projects.projects['x'] = _project('x', Craft.crossStitch);
    patterns.byProject['x'] = sampleGridPattern(projectId: 'x');
    await cells.setCells('pat-1', const <CellPosition>[CellPosition(0, 0), CellPosition(1, 0)], done: true);
    await work('x', DateTime(2026, 11, 10, 9), const Duration(hours: 1));
    await work('x', DateTime(2026, 11, 12, 9), const Duration(hours: 2));
    final ProjectStats r = (await LoadProjectStats(
      projects: projects,
      sessions: sessions,
      progress: reader,
      clock: clock,
    )('x')).valueOrNull!;
    expect(r.total, const Duration(hours: 3));
    expect(r.sessionCount, 2);
    expect(r.averageSession, const Duration(hours: 1, minutes: 30));
    expect(r.firstDay, DateTime(2026, 11, 10));
    expect(r.lastDay, DateTime(2026, 11, 12));
    expect(r.spanDays, 3);
    expect(r.recentDays.first.key, DateTime(2026, 11, 12));
    expect(r.progress!.done, 2);
    expect(r.pace, isNotNull);
  });

  test('проект без сессий: нули, без темпа; нет проекта — ошибка', () async {
    projects.projects['x'] = _project('x', Craft.crossStitch);
    final LoadProjectStats load = LoadProjectStats(
      projects: projects,
      sessions: sessions,
      progress: reader,
      clock: clock,
    );
    final ProjectStats r = (await load('x')).valueOrNull!;
    expect((r.total, r.sessionCount, r.spanDays, r.pace), (Duration.zero, 0, 0, null));
    expect((await load('nope')).valueOrNull, isNull);
  });

  test('обзор: проекты за период, больше времени выше, при равенстве вышивка выше бисера', () async {
    projects.projects['b'] = _project('b', Craft.beading);
    projects.projects['x'] = _project('x', Craft.crossStitch);
    projects.projects['old'] = _project('old', Craft.beading);
    await work('b', DateTime(2026, 11, 10, 9), const Duration(hours: 1));
    await work('x', DateTime(2026, 11, 11, 9), const Duration(hours: 1));
    await work('old', DateTime(2026, 9, 1, 9), const Duration(hours: 5));
    final StatsOverview o = (await LoadStatsOverview(
      projects: projects,
      sessions: sessions,
      progress: reader,
      clock: clock,
    )(StatsPeriod.week)).valueOrNull!;
    expect(o.stats.total, const Duration(hours: 2));
    expect(o.rows.map((r) => r.project.id), <String>['x', 'b']);
    expect(o.rows.first.totalTime, const Duration(hours: 1));
    expect(o.isEmpty, isFalse);
  });

  test('обзор за период без работы пуст', () async {
    final StatsOverview o = (await LoadStatsOverview(
      projects: projects,
      sessions: sessions,
      progress: reader,
      clock: clock,
    )(StatsPeriod.week)).valueOrNull!;
    expect(o.isEmpty, isTrue);
    expect(o.rows, isEmpty);
  });
}
