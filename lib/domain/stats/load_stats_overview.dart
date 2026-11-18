import 'package:beading/core/clock.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/stats/project_progress.dart';
import 'package:beading/domain/stats/stats_overview.dart';
import 'package:beading/domain/stats/stats_range.dart';
import 'package:beading/domain/stats/work_stats_calculator.dart';
import 'package:beading/domain/weaving/work_session.dart';
import 'package:beading/domain/weaving/work_session_repository.dart';

/// Собирает [StatsOverview] за период из сессий всех живых проектов.
class LoadStatsOverview {
  const LoadStatsOverview({
    required ProjectRepository projects,
    required WorkSessionRepository sessions,
    required ProjectProgressReader progress,
    required Clock clock,
    WorkStatsCalculator calculator = const WorkStatsCalculator(),
  }) : _projects = projects,
       _sessions = sessions,
       _progress = progress,
       _clock = clock,
       _calculator = calculator;

  final ProjectRepository _projects;
  final WorkSessionRepository _sessions;
  final ProjectProgressReader _progress;
  final Clock _clock;
  final WorkStatsCalculator _calculator;

  Future<Result<StatsOverview>> call(StatsPeriod period, {int offset = 0, int weekStart = DateTime.monday}) async {
    final Result<List<WorkSession>> loaded = await _sessions.all();
    if (loaded case Err<List<WorkSession>>(:final failure)) {
      return Err<StatsOverview>(failure);
    }
    final List<WorkSession> sessions = loaded.valueOrNull!;
    final DateTime now = _clock.now();
    final StatsRange range = StatsRange.of(period, now, weekStart: weekStart, offset: offset);
    final Map<String, Project> projects = <String, Project>{
      for (final Project p in await _projects.watchAll().first) p.id: p,
    };
    final Map<String, Duration> inPeriod = _calculator.byProject(sessions, range, now);
    final Map<String, Duration> overall = _calculator.byProject(sessions, StatsRange.all(now), now);
    final List<MapEntry<String, Duration>> shown =
        inPeriod.entries.where((e) => e.value > Duration.zero && projects.containsKey(e.key)).toList()..sort((a, b) {
          final int byTime = b.value.compareTo(a.value);
          if (byTime != 0) {
            return byTime;
          }
          return _craftRank(projects[a.key]!).compareTo(_craftRank(projects[b.key]!));
        });
    final List<ProjectTimeRow> rows = <ProjectTimeRow>[
      for (final MapEntry<String, Duration> e in shown)
        ProjectTimeRow(
          project: projects[e.key]!,
          periodTime: e.value,
          totalTime: overall[e.key] ?? e.value,
          progress: await _progress.read(projects[e.key]!),
        ),
    ];
    return Success<StatsOverview>(StatsOverview(stats: _calculator.compute(sessions, range, now), rows: rows));
  }

  /// Вышивка первая.
  int _craftRank(Project p) => p.craft == Craft.crossStitch ? 0 : 1;
}
