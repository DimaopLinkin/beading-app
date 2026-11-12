import 'package:beading/app/app.dart';
import 'package:beading/app/composition/app_dependencies.dart';
import 'package:beading/app/composition/core_module.dart';
import 'package:beading/app/di.dart';
import 'package:beading/app/platform/app_lifecycle_binding.dart';
import 'package:beading/app/platform/desktop_window.dart';
import 'package:beading/app/platform/orientation_lock.dart';
import 'package:beading/app/startup_failure_app.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/open_database.dart';
import 'package:beading/domain/settings/reduce_transparency_source.dart';
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
  ReduceTransparencySource? reduceTransparencySource,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppDependencies dependencies = AppDependencies(
    core: CoreModule(database: database ?? await openAppDatabase(), reduceTransparency: reduceTransparencySource),
  );
  await configureDependencies(dependencies);
  await (orientationLock ?? getIt<OrientationLock>()).lockPortrait();
  await (desktopWindow ?? getIt<DesktopWindow>()).configure(const DesktopWindowConfig());
  final WakelockController wakelock = wakelockController ?? getIt<WakelockController>();
  await wakelock.start();
  // Живёт всё время работы приложения.
  AppLifecycleBinding(wakelock);
  // Битый файл каталога не должен мешать запуску: остальные файлы загружены, ошибка уходит в журнал.
  final Result<void> seeded = await dependencies.catalog.seeder.seed();
  if (seeded case Err<void>(:final failure)) {
    debugPrint('Каталог загружен не полностью: ${failure.message}');
  }
  return BeadingApp(dependencies: dependencies);
}

/// [bootstrap], который не бросает: если запуск не удался (база не открылась, миграция упала), возвращает экран
/// с объяснением вместо пустого окна.
Future<Widget> bootstrapSafely({
  AppDatabase? database,
  OrientationLock? orientationLock,
  DesktopWindow? desktopWindow,
  WakelockController? wakelockController,
  ReduceTransparencySource? reduceTransparencySource,
}) async {
  try {
    return await bootstrap(
      database: database,
      orientationLock: orientationLock,
      desktopWindow: desktopWindow,
      wakelockController: wakelockController,
      reduceTransparencySource: reduceTransparencySource,
    );
  } on Object catch (error, stack) {
    debugPrint('Запуск не удался: $error\n$stack');
    return StartupFailureApp(error: error);
  }
}
