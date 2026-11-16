import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/stats/project_progress.dart';
import 'package:beading/domain/stats/work_stats.dart';
import 'package:equatable/equatable.dart';

/// Строка списка «По работам»: проект, время за период и всего, прогресс на сегодня.
final class ProjectTimeRow extends Equatable {
  const ProjectTimeRow({required this.project, required this.periodTime, required this.totalTime, this.progress});

  final Project project;
  final Duration periodTime;
  final Duration totalTime;
  final ProjectProgress? progress;

  @override
  List<Object?> get props => <Object?>[project, periodTime, totalTime, progress];
}

/// Всё для экрана «Статистика» за выбранный период.
final class StatsOverview extends Equatable {
  const StatsOverview({required this.stats, required this.rows});

  final WorkStats stats;

  /// Проекты с работой за период: больше времени выше, при равенстве вышивка выше бисера.
  final List<ProjectTimeRow> rows;

  /// Работы за период не было.
  bool get isEmpty => stats.total == Duration.zero;

  @override
  List<Object?> get props => <Object?>[stats, rows];
}
