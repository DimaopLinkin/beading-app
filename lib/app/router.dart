import 'package:beading/app/di.dart';
import 'package:beading/core/clock.dart';
import 'package:beading/domain/settings/app_info.dart';
import 'package:beading/domain/settings/secret_tap_handler.dart';
import 'package:beading/presentation/library/library_screen.dart';
import 'package:beading/presentation/settings/about_screen.dart';
import 'package:beading/presentation/settings/hidden_settings_screen.dart';
import 'package:beading/presentation/settings/settings_screen.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const String library = '/';
  static const String settings = '/settings';
  static const String about = '/settings/about';
  static const String hidden = '/settings/about/hidden';
}

/// Все страницы настроек делят [SettingsCubit] из корня приложения ([BeadingApp]).
GoRouter createRouter() => GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.library,
      builder: (context, _) => LibraryScreen(onOpenSettings: () => context.push(AppRoutes.settings)),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, _) => SettingsScreen(onOpenAbout: () => context.push(AppRoutes.about)),
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
  ],
);
