import 'package:beading/core/clock.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/stats/project_pace.dart';
import 'package:beading/domain/stats/project_progress.dart';
import 'package:beading/domain/stats/project_stats.dart';
import 'package:beading/domain/stats/stats_range.dart';
import 'package:beading/domain/stats/work_stats.dart';
import 'package:beading/domain/stats/work_stats_calculator.dart';
import 'package:beading/domain/weaving/work_session.dart';
import 'package:beading/domain/weaving/work_session_repository.dart';

/// Собирает [ProjectStats]: время из сессий проекта, прогресс из хранилищ схемы.
class LoadProjectStats {
  const LoadProjectStats({
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

  Future<Result<ProjectStats>> call(String projectId) async {
    final Result<Project> found = await _projects.get(projectId);
    if (found case Err<Project>(:final failure)) {
      return Err<ProjectStats>(failure);
    }
    final Project project = found.valueOrNull!;
    final Result<List<WorkSession>> loaded = await _sessions.byProject(projectId);
    if (loaded case Err<List<WorkSession>>(:final failure)) {
      return Err<ProjectStats>(failure);
    }
    final List<WorkSession> sessions = loaded.valueOrNull!;
    final DateTime now = _clock.now();
    final WorkStats stats = _calculator.compute(sessions, StatsRange.all(now), now);
    final int count = sessions.where((s) => s.duration > Duration.zero).length;
    final List<DateTime> days = stats.perDay.keys.toList()..sort();
    final List<MapEntry<DateTime, Duration>> recent = <MapEntry<DateTime, Duration>>[
      for (final DateTime day in days.reversed.take(14)) MapEntry<DateTime, Duration>(day, stats.perDay[day]!),
    ];
    final ProjectProgress? progress = await _progress.read(project);
    return Success<ProjectStats>(
      ProjectStats(
        project: project,
        total: stats.total,
        sessionCount: count,
        averageSession: count == 0 ? Duration.zero : Duration(microseconds: stats.total.inMicroseconds ~/ count),
        firstDay: days.isEmpty ? null : days.first,
        lastDay: days.isEmpty ? null : days.last,
        recentDays: recent,
        progress: progress,
        pace: progress == null
            ? null
            : ProjectPace.estimate(done: progress.done, total: progress.total, worked: stats.total),
      ),
    );
  }
}
