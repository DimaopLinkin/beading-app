import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';

/// Главный экран «Мои работы». Пока пустой: список проектов появится в T05.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(middle: Text(AppLocalizations.of(context).libraryTitle)),
    child: const SizedBox.expand(),
  );
}
