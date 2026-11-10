import 'package:beading/app/di.dart';
import 'package:beading/core/clock.dart';
import 'package:beading/domain/settings/app_info.dart';
import 'package:beading/domain/settings/secret_tap_handler.dart';
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
        onImportBook: () => context.push<String>(AppRoutes.importBook),
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
  ],
);
