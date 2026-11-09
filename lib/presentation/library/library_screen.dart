import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:flutter/cupertino.dart';

/// Главный экран «Мои работы». Пока пустой: список проектов появится в T05.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({this.onOpenSettings, super.key});

  /// Открывает настройки; `null` — кнопки нет.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.libraryTitle),
        trailing: onOpenSettings == null
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(44),
                onPressed: onOpenSettings,
                child: Semantics(label: l10n.settingsTitle, child: const Icon(AppIcons.settings)),
              ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
