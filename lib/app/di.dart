import 'package:beading/app/platform/desktop_window.dart';
import 'package:beading/app/platform/orientation_lock.dart';
import 'package:beading/core/clock.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/data/platform/wakelock_plus_screen_wake_lock.dart';
import 'package:beading/data/settings/in_memory_keep_screen_awake_setting.dart';
import 'package:beading/data/settings/in_memory_settings_repository.dart';
import 'package:beading/domain/settings/keep_screen_awake_setting.dart';
import 'package:beading/domain/settings/screen_wake_lock.dart';
import 'package:beading/domain/settings/settings_repository.dart';
import 'package:beading/domain/settings/wakelock_controller.dart';
import 'package:beading/presentation/theme/theme_mode_cubit.dart';
import 'package:get_it/get_it.dart';

/// Глобальный контейнер зависимостей. Регистрируем только здесь.
final GetIt getIt = GetIt.instance;

/// Регистрирует сервисы в [locator]. Вызывается один раз при запуске (и в каждом тесте заново):
/// повторный вызов сначала сбрасывает прежние регистрации.
Future<void> configureDependencies([GetIt? locator]) async {
  final GetIt container = locator ?? getIt;
  await container.reset();
  container
    ..registerLazySingleton<Clock>(SystemClock.new)
    ..registerLazySingleton<IdGenerator>(() => UuidV7IdGenerator(clock: container<Clock>()))
    ..registerLazySingleton<OrientationLock>(SystemChromeOrientationLock.new)
    ..registerLazySingleton<DesktopWindow>(WindowManagerDesktopWindow.new)
    ..registerLazySingleton<ScreenWakeLock>(WakelockPlusScreenWakeLock.new)
    // До T03 настройка живёт в памяти.
    ..registerLazySingleton<KeepScreenAwakeSetting>(InMemoryKeepScreenAwakeSetting.new)
    ..registerLazySingleton<WakelockController>(
      () => WakelockController(wakeLock: container<ScreenWakeLock>(), setting: container<KeepScreenAwakeSetting>()),
    )
    // До T03 настройки живут в памяти.
    ..registerLazySingleton<SettingsRepository>(InMemorySettingsRepository.new)
    ..registerFactory<ThemeModeCubit>(() => ThemeModeCubit(container<SettingsRepository>()));
}
