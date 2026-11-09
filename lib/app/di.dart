import 'package:beading/core/clock.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/open_database.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/data/settings/drift_settings_repository.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:beading/domain/settings/settings_repository.dart';
import 'package:beading/presentation/theme/theme_mode_cubit.dart';
import 'package:get_it/get_it.dart';

/// Глобальный контейнер зависимостей. Регистрируем только здесь.
final GetIt getIt = GetIt.instance;

/// Регистрирует сервисы в [locator]. Вызывается один раз при запуске (и в каждом тесте заново):
/// повторный вызов сначала сбрасывает прежние регистрации.
///
/// [database] — готовая база (в тестах — в памяти); без неё открывается файл в Application Support.
Future<void> configureDependencies([GetIt? locator, AppDatabase? database]) async {
  final GetIt container = locator ?? getIt;
  await container.reset();
  final AppDatabase db = database ?? await openAppDatabase();
  container
    ..registerSingleton<AppDatabase>(db, dispose: (value) => value.close())
    ..registerLazySingleton<Clock>(SystemClock.new)
    ..registerLazySingleton<IdGenerator>(() => UuidV7IdGenerator(clock: container<Clock>()))
    ..registerLazySingleton<DeviceIdProvider>(
      () => DriftDeviceIdProvider(dao: db.settingsDao, ids: container<IdGenerator>(), clock: container<Clock>()),
    )
    ..registerLazySingleton<SettingsRepository>(
      () => DriftSettingsRepository(
        dao: db.settingsDao,
        deviceIds: container<DeviceIdProvider>(),
        clock: container<Clock>(),
      ),
    )
    ..registerFactory<ThemeModeCubit>(() => ThemeModeCubit(container<SettingsRepository>()));
}
