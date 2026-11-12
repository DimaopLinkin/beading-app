import 'package:beading/app/composition/app_routes.dart';
import 'package:beading/app/composition/catalog_module.dart';
import 'package:beading/app/composition/core_module.dart';
import 'package:beading/app/composition/grid_module.dart';
import 'package:beading/app/composition/projects_module.dart';
import 'package:beading/app/composition/weaving_module.dart';
import 'package:beading/domain/materials/use_cases/load_project_floss.dart';
import 'package:beading/presentation/floss/floss_cubit.dart';
import 'package:beading/presentation/floss/floss_screen.dart';
import 'package:beading/presentation/stitching/stitch_cubit.dart';
import 'package:beading/presentation/stitching/stitch_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Вышивка крестом: отметки крестиков и расход мулине (ADR-0007).
final class StitchingModule {
  StitchingModule({
    required CoreModule core,
    required ProjectsModule projects,
    required GridModule grid,
    required WeavingModule weaving,
    required CatalogModule catalog,
  }) : _core = core,
       _projects = projects,
       _grid = grid,
       _weaving = weaving,
       _catalog = catalog;

  final CoreModule _core;
  final ProjectsModule _projects;
  final GridModule _grid;
  final WeavingModule _weaving;
  final CatalogModule _catalog;

  LoadProjectFloss loadProjectFloss() => LoadProjectFloss(_grid.patterns, progress: _grid.cellProgress);

  StitchCubit stitchCubit(String projectId) => StitchCubit(
    projectId: projectId,
    projects: _projects.repository,
    patterns: _grid.patterns,
    cellProgress: _grid.cellProgress,
    progress: _grid.progress,
    markCells: _grid.markCells(),
    markRect: _grid.markRect(),
    markColor: _grid.markColor(),
    settings: _core.settings,
    recordProgress: _projects.recordBookProgress(),
    changeStatus: _projects.changeProjectStatus(),
    tracker: _weaving.workSessionTracker(),
    events: _core.events,
  );

  FlossCubit flossCubit(String projectId) => FlossCubit(
    projectId: projectId,
    loadFloss: loadProjectFloss(),
    projects: _projects.repository,
    stock: _catalog.flossStock,
  );

  List<RouteBase> routes() => <RouteBase>[
    GoRoute(
      path: StitchScreen.routePath,
      builder: (context, state) => BlocProvider<StitchCubit>(
        create: (_) => stitchCubit(state.pathParameters['projectId']!)..load(),
        child: StitchScreen(onOpenFloss: () => context.push(AppRoutes.floss(state.pathParameters['projectId']!))),
      ),
    ),
    GoRoute(
      path: FlossScreen.routePath,
      builder: (_, state) => BlocProvider<FlossCubit>(
        create: (_) => flossCubit(state.pathParameters['projectId']!)..load(),
        child: FlossScreen(sharer: _core.textSharer),
      ),
    ),
  ];
}
