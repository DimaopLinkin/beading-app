import 'package:beading/app/app.dart';
import 'package:beading/app/di.dart';
import 'package:flutter/widgets.dart';

/// Готовит приложение к запуску и возвращает корневой виджет.
Future<Widget> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  return const BeadingApp();
}
