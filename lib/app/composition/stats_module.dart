import 'package:beading/app/composition/core_module.dart';
import 'package:beading/app/composition/grid_module.dart';
import 'package:beading/app/composition/projects_module.dart';
import 'package:beading/app/composition/weaving_module.dart';
import 'package:beading/domain/stats/load_project_stats.dart';
import 'package:beading/domain/stats/load_stats_overview.dart';
import 'package:beading/domain/stats/project_progress.dart';
import 'package:beading/presentation/stats/project_stats_cubit.dart';
import 'package:beading/presentation/stats/project_stats_sheet.dart';
import 'package:beading/presentation/stats/stats_cubit.dart';
import 'package:beading/presentation/stats/stats_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Статистика времени и прогресса (T32): экран «Статистика» и лист «Статистика проекта» (ADR-0007).
final class StatsModule {
  StatsModule({
    required CoreModule core,
    required ProjectsModule projects,
    required GridModule grid,
    required WeavingModule weaving,
  }) : _core = core,
       _projects = projects,
       _grid = grid,
       _weaving = weaving;

  final CoreModule _core;
  final ProjectsModule _projects;
  final GridModule _grid;
  final WeavingModule _weaving;

  ProjectProgressReader progressReader() =>
      ProjectProgressReader(patterns: _grid.patterns, rows: _grid.progress, cells: _grid.cellProgress);

  LoadStatsOverview loadOverview() => LoadStatsOverview(
    projects: _projects.repository,
    sessions: _weaving.sessions,
    progress: progressReader(),
    clock: _core.clock,
  );

  LoadProjectStats loadProjectStats() => LoadProjectStats(
    projects: _projects.repository,
    sessions: _weaving.sessions,
    progress: progressReader(),
    clock: _core.clock,
  );

  StatsCubit statsCubit() => StatsCubit(load: loadOverview(), sessions: _weaving.sessions, clock: _core.clock);

  ProjectStatsCubit projectStatsCubit(String projectId) =>
      ProjectStatsCubit(projectId: projectId, load: loadProjectStats());

  /// Показывает лист «Статистика проекта» поверх текущего экрана.
  Future<void> showProjectStats(BuildContext context, String projectId) => showCupertinoSheet<void>(
    context: context,
    builder: (_) => BlocProvider<ProjectStatsCubit>(
      create: (_) => projectStatsCubit(projectId)..load(),
      child: ProjectStatsSheet(now: _core.clock.now()),
    ),
  );

  List<RouteBase> routes() => <RouteBase>[
    GoRoute(
      path: StatsScreen.routePath,
      builder: (context, _) => BlocProvider<StatsCubit>(
        create: (_) => statsCubit()..load(),
        child: StatsScreen(
          onOpenProject: (context, project) => showProjectStats(context, project.id),
        ),
      ),
    ),
  ];
}
