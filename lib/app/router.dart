import 'dart:async';

import 'package:beading/app/di.dart';
import 'package:beading/core/clock.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/settings/app_info.dart';
import 'package:beading/domain/settings/secret_tap_handler.dart';
import 'package:beading/domain/sharing/text_sharer.dart';
import 'package:beading/presentation/book_work/book_work_cubit.dart';
import 'package:beading/presentation/book_work/book_work_screen.dart';
import 'package:beading/presentation/catalog/catalog_cubit.dart';
import 'package:beading/presentation/catalog/catalog_screen.dart';
import 'package:beading/presentation/dev/glass_check_screen.dart';
import 'package:beading/presentation/editor/editor_cubit.dart';
import 'package:beading/presentation/editor/editor_screen.dart';
import 'package:beading/presentation/editor/new_grid_cubit.dart';
import 'package:beading/presentation/editor/new_grid_screen.dart';
import 'package:beading/presentation/import_book/import_book_cubit.dart';
import 'package:beading/presentation/import_book/import_book_screen.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/library_cubit.dart';
import 'package:beading/presentation/library/library_screen.dart';
import 'package:beading/presentation/library/new_project_entry.dart';
import 'package:beading/presentation/library/project_thumbnail_provider.dart';
import 'package:beading/presentation/materials/materials_cubit.dart';
import 'package:beading/presentation/materials/materials_screen.dart';
import 'package:beading/presentation/settings/about_screen.dart';
import 'package:beading/presentation/settings/hidden_settings_screen.dart';
import 'package:beading/presentation/settings/settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const String library = '/';
  static const String settings = '/settings';
  static const String about = '/settings/about';
  static const String hidden = '/settings/about/hidden';
  static const String glassCheck = '/settings/glass-check';

  /// «Схема из книги». Закрывается с id созданного проекта.
  static const String importBook = ImportBookScreen.routePath;

  /// Каталог цветов бисера (T20).
  static const String catalog = CatalogScreen.routePath;

  /// Материалы проекта: расход бисера по цветам схемы (T20).
  static String materials(String projectId) => MaterialsScreen.locationFor(projectId);

  /// Работа по схеме из книги (T07): линейка, зум, страницы, заметки. T05 откроет её из карточки проекта.
  /// Лист создания схемы (T17). Закрывается с id созданного проекта.
  static const String newGrid = NewGridScreen.routePath;

  /// Редактор сеточной схемы (T17).
  static String editor(String projectId) => EditorScreen.locationFor(projectId);

  static String bookWork(String projectId) => BookWorkScreen.locationFor(projectId);
}

/// Все страницы настроек делят [SettingsCubit] из корня приложения ([BeadingApp]).
///
/// [showDeveloperTools] — раздел «Для разработки» (проверка стекла); по умолчанию только вне релизной сборки.
GoRouter createRouter({bool showDeveloperTools = !kReleaseMode}) => GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.library,
      builder: (context, _) => BlocProvider<LibraryCubit>(
        create: (_) => getIt<LibraryCubit>()..start(),
        child: LibraryScreen(
          newProjects: getIt<NewProjectRegistry>(),
          thumbnails: getIt<ProjectThumbnailRegistry>(),
          onOpenSettings: () => context.push(AppRoutes.settings),
          onOpenCatalog: () => context.push(AppRoutes.catalog),
          onOpenMaterials: (context, project) => context.push(AppRoutes.materials(project.id)),
          onOpenProject: (context, project) {
            if (project.contentKind == ContentKind.image) {
              unawaited(context.push<void>(AppRoutes.bookWork(project.id)));
            } else if (project.contentKind == ContentKind.grid) {
              unawaited(context.push<void>(AppRoutes.editor(project.id)));
            }
          },
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, _) => SettingsScreen(
        onOpenAbout: () => context.push(AppRoutes.about),
        onOpenGlassCheck: showDeveloperTools ? () => context.push(AppRoutes.glassCheck) : null,
      ),
    ),
    GoRoute(
      path: AppRoutes.about,
      builder: (context, _) => AboutScreen(
        appInfoProvider: getIt<AppInfoProvider>(),
        clock: getIt<Clock>(),
        secretTapHandler: getIt<SecretTapHandler>(),
        onOpenHidden: () => context.push(AppRoutes.hidden),
      ),
    ),
    GoRoute(path: AppRoutes.hidden, builder: (_, _) => const HiddenSettingsScreen()),
    if (showDeveloperTools) GoRoute(path: AppRoutes.glassCheck, builder: (_, _) => const GlassCheckScreen()),
    GoRoute(
      path: AppRoutes.importBook,
      builder: (_, _) => BlocProvider<ImportBookCubit>(
        create: (_) => getIt<ImportBookCubit>(),
        child: const ImportBookScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.newGrid,
      builder: (context, _) => BlocProvider<NewGridCubit>(
        create: (_) => getIt<NewGridCubit>(param1: AppLocalizations.of(context).newGridDefaultName),
        child: const NewGridScreen(),
      ),
    ),
    GoRoute(
      path: EditorScreen.routePath,
      builder: (_, state) => BlocProvider<EditorCubit>(
        create: (_) => getIt<EditorCubit>(param1: state.pathParameters['projectId'])..load(),
        child: EditorScreen(catalog: getIt<CatalogRepository>()),
      ),
    ),
    GoRoute(
      path: AppRoutes.catalog,
      builder: (_, _) => BlocProvider<CatalogCubit>(
        create: (_) => getIt<CatalogCubit>()..start(),
        child: const CatalogScreen(),
      ),
    ),
    GoRoute(
      path: MaterialsScreen.routePath,
      builder: (_, state) => BlocProvider<MaterialsCubit>(
        create: (_) => getIt<MaterialsCubit>(param1: state.pathParameters['projectId'])..load(),
        child: MaterialsScreen(sharer: getIt<TextSharer>()),
      ),
    ),
    GoRoute(
      path: BookWorkScreen.routePath,
      builder: (_, state) => BlocProvider<BookWorkCubit>(
        create: (_) => getIt<BookWorkCubit>(param1: state.pathParameters['projectId'])..load(),
        child: BookWorkScreen(files: getIt<FileStore>()),
      ),
    ),
  ],
);
