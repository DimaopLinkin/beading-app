import 'package:beading/app/composition/app_routes.dart';
import 'package:beading/app/composition/core_module.dart';
import 'package:beading/app/composition/grid_module.dart';
import 'package:beading/app/composition/projects_module.dart';
import 'package:beading/data/weaving/drift_work_session_repository.dart';
import 'package:beading/domain/materials/use_cases/load_project_materials.dart';
import 'package:beading/domain/weaving/rows_counter.dart';
import 'package:beading/domain/weaving/work_session_content_cleaner.dart';
import 'package:beading/domain/weaving/work_session_repository.dart';
import 'package:beading/domain/weaving/work_session_tracker.dart';
import 'package:beading/presentation/materials/materials_cubit.dart';
import 'package:beading/presentation/materials/materials_screen.dart';
import 'package:beading/presentation/weaving/weave_cubit.dart';
import 'package:beading/presentation/weaving/weave_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Плетение бисером: счётчик рядов, время работы и расход бисера (ADR-0007).
final class WeavingModule {
  WeavingModule({
    required CoreModule core,
    required ProjectsModule projects,
    required GridModule grid,
  }) : _core = core,
       _projects = projects,
       _grid = grid;

  final CoreModule _core;
  final ProjectsModule _projects;
  final GridModule _grid;

  late final WorkSessionRepository sessions = DriftWorkSessionRepository(
    dao: _core.database.workSessionsDao,
    deviceIds: _core.deviceIds,
    clock: _core.clock,
    ids: _core.ids,
  );

  late final WorkSessionContentCleaner contentCleaner = WorkSessionContentCleaner(sessions);

  RowsCounter rowsCounter() => RowsCounter(settings: _core.settings, events: _core.events);

  /// Отдельный счётчик времени на каждый экран плетения или вышивки.
  WorkSessionTracker workSessionTracker() => WorkSessionTracker(sessions: sessions, clock: _core.clock);

  LoadProjectMaterials loadProjectMaterials() => LoadProjectMaterials(_grid.patterns);

  WeaveCubit weaveCubit(String projectId) => WeaveCubit(
    projectId: projectId,
    projects: _projects.repository,
    patterns: _grid.patterns,
    progress: _grid.progress,
    settings: _core.settings,
    recordProgress: _projects.recordBookProgress(),
    changeStatus: _projects.changeProjectStatus(),
    rowsCounter: rowsCounter(),
    tracker: workSessionTracker(),
  );

  MaterialsCubit materialsCubit(String projectId) => MaterialsCubit(
    projectId: projectId,
    loadMaterials: loadProjectMaterials(),
    projects: _projects.repository,
  );

  List<RouteBase> routes() => <RouteBase>[
    GoRoute(
      path: WeaveScreen.routePath,
      builder: (context, state) => BlocProvider<WeaveCubit>(
        create: (_) => weaveCubit(state.pathParameters['projectId']!)..load(),
        child: WeaveScreen(onOpenEditor: () => context.push(AppRoutes.editor(state.pathParameters['projectId']!))),
      ),
    ),
    GoRoute(
      path: MaterialsScreen.routePath,
      builder: (_, state) => BlocProvider<MaterialsCubit>(
        create: (_) => materialsCubit(state.pathParameters['projectId']!)..load(),
        child: MaterialsScreen(sharer: _core.textSharer),
      ),
    ),
  ];
}
