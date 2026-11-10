import 'dart:async';

import 'package:beading/app/di.dart';
import 'package:beading/app/platform/app_menu_bar.dart';
import 'package:beading/app/router.dart';
import 'package:beading/domain/easter_eggs/easter_egg_service.dart';
import 'package:beading/domain/easter_eggs/long_session_watcher.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:beading/domain/settings/reduce_transparency_source.dart';
import 'package:beading/domain/sharing/biser/biser_file_source.dart';
import 'package:beading/presentation/easter_eggs/compliment_banner_cubit.dart';
import 'package:beading/presentation/easter_eggs/compliment_overlay.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/settings/settings_cubit.dart';
import 'package:beading/presentation/sharing/data_transfer_cubit.dart';
import 'package:beading/presentation/sharing/data_transfer_host.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:beading/presentation/theme/theme_mode_cubit.dart';
import 'package:beading/presentation/widgets/dismiss_focus_on_tap.dart';
import 'package:beading/presentation/widgets/glass/reduce_transparency_scope.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BeadingApp extends StatefulWidget {
  const BeadingApp({super.key});

  @override
  State<BeadingApp> createState() => _BeadingAppState();
}

class _BeadingAppState extends State<BeadingApp> {
  late final GoRouter _router = createRouter();
  late final ThemeModeCubit _themeModeCubit = getIt<ThemeModeCubit>()..restore();
  late final SettingsCubit _settingsCubit = getIt<SettingsCubit>()..load();
  final ComplimentBannerCubit _complimentCubit = getIt<ComplimentBannerCubit>();
  final EasterEggService _easterEggs = getIt<EasterEggService>();
  final LongSessionWatcher _longSession = getIt<LongSessionWatcher>();

  @override
  void initState() {
    super.initState();
    // Баннер уже слушает поток комплиментов (cubit создан в поле), теперь можно запускать пасхалки.
    _easterEggs.start();
    _longSession.start();
    getIt<AppEvents>().publish(const AppStarted());
  }

  @override
  void dispose() {
    _router.dispose();
    _longSession.dispose();
    unawaited(_easterEggs.dispose());
    unawaited(_complimentCubit.close());
    unawaited(_themeModeCubit.close());
    unawaited(_settingsCubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: <BlocProvider<dynamic>>[
      BlocProvider<ThemeModeCubit>.value(value: _themeModeCubit),
      BlocProvider<SettingsCubit>.value(value: _settingsCubit),
      BlocProvider<ComplimentBannerCubit>.value(value: _complimentCubit),
    ],
    child: BlocBuilder<ThemeModeCubit, AppThemeMode>(
      builder: (context, mode) => AppMenuBar(
        actions: AppMenuActions(onPreferences: () => unawaited(_router.push(AppRoutes.settings))),
        child: CupertinoApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          routerConfig: _router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          theme: switch (mode) {
            AppThemeMode.system => AppTheme.system,
            AppThemeMode.light => AppTheme.light,
            AppThemeMode.dark => AppTheme.dark,
          },
          builder: (context, child) => AppTheme.builder(
            context,
            ReduceTransparencyScope(
              source: getIt<ReduceTransparencySource>(),
              child: DismissFocusOnTap(
                child: DataTransferHost(
                  cubit: getIt<DataTransferCubit>(),
                  incoming: getIt<IncomingBiserFiles>(),
                  navigatorKey: _router.routerDelegate.navigatorKey,
                  child: ComplimentOverlay(child: child ?? const SizedBox.shrink()),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
