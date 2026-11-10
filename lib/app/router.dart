import 'package:beading/app/di.dart';
import 'package:beading/core/clock.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/settings/app_info.dart';
import 'package:beading/domain/settings/secret_tap_handler.dart';
import 'package:beading/presentation/book_work/book_work_cubit.dart';
import 'package:beading/presentation/book_work/book_work_screen.dart';
import 'package:beading/presentation/dev/glass_check_screen.dart';
import 'package:beading/presentation/import_book/import_book_cubit.dart';
import 'package:beading/presentation/import_book/import_book_screen.dart';
import 'package:beading/presentation/library/library_screen.dart';
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

  /// Работа по схеме из книги (T07): линейка, зум, страницы, заметки. T05 откроет её из карточки проекта.
  static String bookWork(String projectId) => BookWorkScreen.locationFor(projectId);
}

/// Все страницы настроек делят [SettingsCubit] из корня приложения ([BeadingApp]).
///
/// [showDeveloperTools] — раздел «Для разработки» (проверка стекла); по умолчанию только вне релизной сборки.
GoRouter createRouter({bool showDeveloperTools = !kReleaseMode}) => GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.library,
      builder: (context, _) => LibraryScreen(
        onOpenSettings: () => context.push(AppRoutes.settings),
        onImportBook: () async {
          // Новая схема сразу открывается для работы.
          final String? projectId = await context.push<String>(AppRoutes.importBook);
          if (projectId != null && context.mounted) {
            await context.push<void>(AppRoutes.bookWork(projectId));
          }
        },
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
      path: BookWorkScreen.routePath,
      builder: (_, state) => BlocProvider<BookWorkCubit>(
        create: (_) => getIt<BookWorkCubit>(param1: state.pathParameters['projectId'])..load(),
        child: BookWorkScreen(files: getIt<FileStore>()),
      ),
    ),
  ],
);
