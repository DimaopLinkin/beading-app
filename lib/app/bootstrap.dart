import 'package:beading/app/app.dart';
import 'package:beading/app/di.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:flutter/widgets.dart';

/// Готовит приложение к запуску и возвращает корневой виджет.
///
/// [database] подменяет файловую базу (в тестах).
Future<Widget> bootstrap({AppDatabase? database}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies(null, database);
  return const BeadingApp();
}
