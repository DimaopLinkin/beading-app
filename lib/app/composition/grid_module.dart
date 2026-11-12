import 'package:beading/app/composition/app_routes.dart';
import 'package:beading/app/composition/catalog_module.dart';
import 'package:beading/app/composition/core_module.dart';
import 'package:beading/app/composition/projects_module.dart';
import 'package:beading/data/grid_pattern/drift_cell_progress_store.dart';
import 'package:beading/data/grid_pattern/drift_grid_pattern_repository.dart';
import 'package:beading/data/grid_pattern/drift_grid_progress_store.dart';
import 'package:beading/domain/grid_pattern/cell_progress_store.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_content.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/grid_progress_store.dart';
import 'package:beading/domain/grid_pattern/use_cases/cell_progress_commands.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/grid_pattern/use_cases/save_grid_pattern.dart';
import 'package:beading/domain/grid_pattern/use_cases/shift_progress.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/presentation/editor/editor_cubit.dart';
import 'package:beading/presentation/editor/editor_screen.dart';
import 'package:beading/presentation/editor/new_grid_cubit.dart';
import 'package:beading/presentation/editor/new_grid_screen.dart';
import 'package:beading/presentation/editor/new_stitch_cubit.dart';
import 'package:beading/presentation/editor/new_stitch_screen.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/pattern_template/pattern_template_cubit.dart';
import 'package:beading/presentation/pattern_template/pattern_template_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Сеточные схемы: хранилища, создание, редактор и «Узор по шаблону» (ADR-0007).
final class GridModule {
  GridModule({
    required CoreModule core,
    required ProjectsModule projects,
    required CatalogModule catalog,
  }) : _core = core,
       _projects = projects,
       _catalog = catalog;

  final CoreModule _core;
  final ProjectsModule _projects;
  final CatalogModule _catalog;

  late final GridPatternRepository patterns = DriftGridPatternRepository(
    dao: _core.database.gridPatternsDao,
    deviceIds: _core.deviceIds,
    clock: _core.clock,
    ids: _core.ids,
  );

  late final GridProgressStore progress = DriftGridProgressStore(
    dao: _core.database.gridPatternsDao,
    deviceIds: _core.deviceIds,
    clock: _core.clock,
    ids: _core.ids,
  );

  late final CellProgressStore cellProgress = DriftCellProgressStore(
    dao: _core.database.gridPatternsDao,
    deviceIds: _core.deviceIds,
    clock: _core.clock,
    ids: _core.ids,
  );

  late final GridPatternContentCleaner contentCleaner = GridPatternContentCleaner(patterns);

  late final GridPatternContentCloner contentCloner = GridPatternContentCloner(patterns: patterns, ids: _core.ids);

  CreateGridPattern createGridPattern() => CreateGridPattern(
    createProject: _projects.createProject(),
    projects: _projects.repository,
    patterns: patterns,
    ids: _core.ids,
  );

  SaveGridPattern saveGridPattern() => SaveGridPattern(patterns);

  MarkCells markCells() => MarkCells(patterns: patterns, progress: cellProgress);

  MarkRect markRect() => MarkRect(patterns: patterns, progress: cellProgress);

  MarkColor markColor() => MarkColor(patterns: patterns, progress: cellProgress);

  EditorCubit editorCubit(String projectId) => EditorCubit(
    projectId: projectId,
    projects: _projects.repository,
    patterns: patterns,
    savePattern: saveGridPattern(),
    touchProject: _projects.touchProject(),
    catalog: _catalog.repository,
    shiftProgress: ShiftProgress(rows: progress, cells: cellProgress),
  );

  NewGridCubit newGridCubit(String defaultName) =>
      NewGridCubit(createPattern: createGridPattern(), defaultName: defaultName);

  NewStitchCubit newStitchCubit(String defaultName) =>
      NewStitchCubit(createPattern: createGridPattern(), defaultName: defaultName);

  PatternTemplateCubit patternTemplateCubit() => PatternTemplateCubit(
    catalog: _catalog.repository,
    settings: _core.settings,
    createPattern: createGridPattern(),
    brandSetting: SettingKeys.defaultBeadBrand,
  );

  List<RouteBase> routes() => <RouteBase>[
    GoRoute(
      path: AppRoutes.newGrid,
      builder: (context, _) => BlocProvider<NewGridCubit>(
        create: (_) => newGridCubit(AppLocalizations.of(context).newGridDefaultName),
        child: const NewGridScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.newStitch,
      builder: (context, _) => BlocProvider<NewStitchCubit>(
        create: (_) => newStitchCubit(AppLocalizations.of(context).newStitchDefaultName),
        child: const NewStitchScreen(),
      ),
    ),
    GoRoute(
      path: EditorScreen.routePath,
      builder: (_, state) => BlocProvider<EditorCubit>(
        create: (_) => editorCubit(state.pathParameters['projectId']!)..load(),
        child: EditorScreen(catalog: _catalog.repository, settings: _core.settings),
      ),
    ),
    GoRoute(
      path: AppRoutes.patternTemplate,
      builder: (_, _) => BlocProvider<PatternTemplateCubit>(
        create: (_) => patternTemplateCubit()..start(),
        child: const PatternTemplateScreen(),
      ),
    ),
  ];
}
