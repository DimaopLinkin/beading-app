import 'package:beading/app/router.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BeadingApp extends StatefulWidget {
  const BeadingApp({super.key});

  @override
  State<BeadingApp> createState() => _BeadingAppState();
}

class _BeadingAppState extends State<BeadingApp> {
  late final GoRouter _router = createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    routerConfig: _router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ru'),
    theme: ThemeData(colorSchemeSeed: Colors.purple, useMaterial3: true),
    darkTheme: ThemeData(colorSchemeSeed: Colors.purple, brightness: Brightness.dark, useMaterial3: true),
  );
}
