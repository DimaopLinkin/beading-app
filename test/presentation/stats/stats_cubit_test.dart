import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/stats/load_stats_overview.dart';
import 'package:beading/domain/stats/project_progress.dart';
import 'package:beading/domain/stats/stats_range.dart';
import 'package:beading/domain/weaving/work_session.dart';
import 'package:beading/presentation/stats/stats_cubit.dart';
import 'package:beading/presentation/stats/stats_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_work_sessions.dart';

Project _project(String id) => Project(
  id: id,
  name: id,
  status: ProjectStatus.inProgress,
  craft: Craft.beading,
  technique: Technique.defaultFor(Craft.beading),
  contentKind: ContentKind.grid,
  notes: '',
  coverPath: null,
  lastWorkedAt: DateTime.utc(2026),
);

void main() {
  late FakeProjectRepository projects;
  late FakeWorkSessionRepository sessions;
  late FakeClock clock;
  late StatsCubit cubit;

  setUp(() {
    projects = FakeProjectRepository()..projects['a'] = _project('a');
    sessions = FakeWorkSessionRepository();
    clock = FakeClock(DateTime(2026, 11, 15, 22));
    cubit = StatsCubit(
      load: LoadStatsOverview(
        projects: projects,
        sessions: sessions,
        progress: ProjectProgressReader(
          patterns: FakeGridPatternRepository(),
          rows: FakeGridProgressStore(),
          cells: FakeCellProgressStore(),
        ),
        clock: clock,
      ),
      sessions: sessions,
      clock: clock,
      debounce: const Duration(milliseconds: 20),
    );
    addTearDown(cubit.close);
  });

  Future<void> work(DateTime start, Duration length) async {
    final WorkSession s = (await sessions.start('a', start)).valueOrNull!;
    await sessions.touch(s.id, start.add(length));
  }

  test('load: неделя, текущий период, итоги посчитаны', () async {
    await work(DateTime(2026, 11, 10, 9), const Duration(hours: 1));
    await cubit.load();
    expect(cubit.state.status, StatsStatus.ready);
    expect(cubit.state.period, StatsPeriod.week);
    expect(cubit.state.overview!.stats.total, const Duration(hours: 1));
  });

  test('смена периода сбрасывает сдвиг; вперёд из текущего нельзя, назад можно', () async {
    await cubit.load();
    expect(cubit.state.canGoNext, isFalse);
    await cubit.previous();
    expect(cubit.state.offset, -1);
    expect(cubit.state.canGoNext, isTrue);
    await cubit.setPeriod(StatsPeriod.month);
    expect(cubit.state.offset, 0);
    await cubit.next();
    expect(cubit.state.offset, 0);
  });

  test('«всё время» не листается', () async {
    await cubit.load();
    await cubit.setPeriod(StatsPeriod.all);
    await cubit.previous();
    expect(cubit.state.offset, 0);
    expect(cubit.state.canGoPrevious, isFalse);
  });

  test('прошлая неделя: считается именно она', () async {
    await work(DateTime(2026, 11, 3, 9), const Duration(hours: 2));
    await cubit.load();
    expect(cubit.state.overview!.isEmpty, isTrue);
    await cubit.previous();
    expect(cubit.state.overview!.stats.total, const Duration(hours: 2));
  });

  test('запись сессии при открытом экране пересчитывает итоги после debounce', () async {
    await cubit.load();
    expect(cubit.state.overview!.isEmpty, isTrue);
    await work(DateTime(2026, 11, 10, 9), const Duration(hours: 1));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(cubit.state.overview!.stats.total, const Duration(hours: 1));
  });
}
