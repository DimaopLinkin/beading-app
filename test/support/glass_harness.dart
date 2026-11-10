import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// Поднимает [child] в `CupertinoApp` с темой и токенами приложения.
Future<void> pumpGlass(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  bool highContrast = false,
}) {
  return tester.pumpWidget(
    CupertinoApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, app) {
        final Widget themed = AppTheme.builder(context, app);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: highContrast),
          child: themed,
        );
      },
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      home: Center(child: child),
    ),
  );
}
