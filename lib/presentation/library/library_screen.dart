import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:flutter/cupertino.dart';

/// Главный экран «Мои работы». Пока пустой: список проектов появится в T05.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({this.onOpenSettings, this.onImportBook, super.key});

  /// Открывает настройки; `null` — кнопки нет.
  final VoidCallback? onOpenSettings;

  /// Временный вход в «Схему из книги»; T05 заменит его пунктом листа «Новый проект». `null` — кнопки нет.
  final VoidCallback? onImportBook;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.libraryTitle),
        leading: onImportBook == null
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(44),
                onPressed: onImportBook,
                child: Semantics(label: l10n.libraryImportBook, child: const Icon(AppIcons.add)),
              ),
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
