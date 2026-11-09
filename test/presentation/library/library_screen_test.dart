import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(ThemeData theme) => MaterialApp(
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const LibraryScreen(),
  );

  for (final ThemeData theme in <ThemeData>[ThemeData.light(), ThemeData.dark()]) {
    testWidgets('показывает заголовок в теме ${theme.brightness}', (tester) async {
      await tester.pumpWidget(wrap(theme));

      expect(find.text('Мои работы'), findsOneWidget);
    });
  }
}
