import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';

/// Экран на случай, когда приложение не смогло запуститься (не открылась база, упала миграция).
///
/// Показывает, что произошло, и текст ошибки, чтобы его можно было скопировать и показать разработчику. Не зависит
/// от DI и базы: этих зависимостей на момент ошибки может не быть.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: Builder(
        builder: (context) {
          final AppLocalizations l10n = AppLocalizations.of(context);
          return CupertinoPageScaffold(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.startupFailedTitle, style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle),
                    const SizedBox(height: 16),
                    Text(l10n.startupFailedBody, style: CupertinoTheme.of(context).textTheme.textStyle),
                    const SizedBox(height: 16),
                    CupertinoTextField.borderless(
                      controller: TextEditingController(text: error.toString()),
                      readOnly: true,
                      maxLines: null,
                      padding: EdgeInsets.zero,
                      style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
