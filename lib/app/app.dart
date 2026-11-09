import 'dart:async';

import 'package:beading/app/di.dart';
import 'package:beading/app/router.dart';
import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:beading/presentation/theme/theme_mode_cubit.dart';
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

  @override
  void dispose() {
    _router.dispose();
    unawaited(_themeModeCubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider<ThemeModeCubit>.value(
    value: _themeModeCubit,
    child: BlocBuilder<ThemeModeCubit, AppThemeMode>(
      builder: (context, mode) => CupertinoApp.router(
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
        builder: AppTheme.builder,
      ),
    ),
  );
}
