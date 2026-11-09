import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Главный экран «Мои работы». Пока пустой: список проектов появится в T05.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context).libraryTitle)),
    body: const SizedBox.expand(),
  );
}
