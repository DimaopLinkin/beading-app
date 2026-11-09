import 'package:beading/app/app.dart';
import 'package:beading/app/di.dart';
import 'package:beading/app/platform/app_lifecycle_binding.dart';
import 'package:beading/app/platform/app_menu_bar.dart';
import 'package:beading/app/platform/desktop_window.dart';
import 'package:beading/app/platform/orientation_lock.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/domain/settings/wakelock_controller.dart';
import 'package:flutter/widgets.dart';

/// Готовит приложение к запуску и возвращает корневой виджет.
///
/// [database] подменяет файловую базу (в тестах). Платформенные адаптеры берутся из DI;
/// их параметры нужны тестам, чтобы подставить фейки.
Future<Widget> bootstrap({
  AppDatabase? database,
  OrientationLock? orientationLock,
  DesktopWindow? desktopWindow,
  WakelockController? wakelockController,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies(database: database);
  await (orientationLock ?? getIt<OrientationLock>()).lockPortrait();
  await (desktopWindow ?? getIt<DesktopWindow>()).configure(const DesktopWindowConfig());
  final WakelockController wakelock = wakelockController ?? getIt<WakelockController>();
  await wakelock.start();
  // Живёт всё время работы приложения.
  AppLifecycleBinding(wakelock);
  return const AppMenuBar(child: BeadingApp());
}
