import 'package:beading/app/composition/app_routes.dart';
import 'package:beading/app/composition/core_module.dart';
import 'package:beading/data/settings/package_info_app_info_provider.dart';
import 'package:beading/domain/settings/app_events_secret_tap_handler.dart';
import 'package:beading/domain/settings/app_info.dart';
import 'package:beading/domain/settings/secret_tap_handler.dart';
import 'package:beading/presentation/dev/glass_check_screen.dart';
import 'package:beading/presentation/settings/about_screen.dart';
import 'package:beading/presentation/settings/hidden_settings_screen.dart';
import 'package:beading/presentation/settings/settings_cubit.dart';
import 'package:beading/presentation/settings/settings_screen.dart';
import 'package:beading/presentation/sharing/data_transfer_cubit.dart';
import 'package:beading/presentation/theme/theme_mode_cubit.dart';
import 'package:go_router/go_router.dart';

/// Настройки, «О приложении» и тема (ADR-0007).
final class SettingsModule {
  SettingsModule({required CoreModule core}) : _core = core;

  final CoreModule _core;

  final AppInfoProvider appInfo = const PackageInfoAppInfoProvider();

  late final SecretTapHandler secretTapHandler = AppEventsSecretTapHandler(_core.events);

  /// Новый на каждый вызов; владелец закрывает сам.
  ThemeModeCubit themeModeCubit() => ThemeModeCubit(_core.settings);

  SettingsCubit settingsCubit() => SettingsCubit(_core.settings);

  /// Маршруты настроек. [dataTransfer] подставляет обмен файлами, пока он не стал модулем.
  List<RouteBase> routes({required bool showDeveloperTools, required DataTransferCubit Function() dataTransfer}) =>
      <RouteBase>[
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, _) => SettingsScreen(
            onOpenAbout: () => context.push(AppRoutes.about),
            onOpenGlassCheck: showDeveloperTools ? () => context.push(AppRoutes.glassCheck) : null,
            dataTransfer: dataTransfer(),
          ),
        ),
        GoRoute(
          path: AppRoutes.about,
          builder: (context, _) => AboutScreen(
            appInfoProvider: appInfo,
            clock: _core.clock,
            secretTapHandler: secretTapHandler,
            onOpenHidden: () => context.push(AppRoutes.hidden),
          ),
        ),
        GoRoute(path: AppRoutes.hidden, builder: (_, _) => const HiddenSettingsScreen()),
        if (showDeveloperTools) GoRoute(path: AppRoutes.glassCheck, builder: (_, _) => const GlassCheckScreen()),
      ];
}
