import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/library_screen.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(CupertinoThemeData theme) => CupertinoApp(
    theme: theme,
    builder: AppTheme.builder,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const LibraryScreen(),
  );

  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('показывает заголовок в теме ${theme.brightness}', (tester) async {
      await tester.pumpWidget(wrap(theme));

      expect(find.text('Мои работы'), findsOneWidget);
    });
  }

  testWidgets('кнопка настроек вызывает onOpenSettings', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      CupertinoApp(
        theme: AppTheme.light,
        builder: AppTheme.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LibraryScreen(onOpenSettings: () => opened++),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Настройки'));

    expect(opened, 1);
  });

  testWidgets('без onOpenSettings кнопки настроек нет', (tester) async {
    await tester.pumpWidget(wrap(AppTheme.light));

    expect(find.bySemanticsLabel('Настройки'), findsNothing);
  });
}
