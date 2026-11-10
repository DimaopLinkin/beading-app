import 'package:beading/app/di.dart';
import 'package:beading/app/platform/desktop_window.dart';
import 'package:beading/app/platform/orientation_lock.dart';
import 'package:beading/core/clock.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/data/easter_eggs/asset_compliment_source.dart';
import 'package:beading/data/easter_eggs/drift_easter_egg_log.dart';
import 'package:beading/data/grid_pattern/drift_grid_pattern_repository.dart';
import 'package:beading/data/grid_pattern/drift_grid_progress_store.dart';
import 'package:beading/data/image_pattern/drift_image_pattern_repository.dart';
import 'package:beading/data/platform/method_channel_reduce_transparency_source.dart';
import 'package:beading/data/platform/wakelock_plus_screen_wake_lock.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/data/settings/drift_settings_repository.dart';
import 'package:beading/data/settings/package_info_app_info_provider.dart';
import 'package:beading/data/settings/repository_keep_screen_awake_setting.dart';
import 'package:beading/domain/easter_eggs/compliment_source.dart';
import 'package:beading/domain/easter_eggs/easter_egg_log.dart';
import 'package:beading/domain/easter_eggs/easter_egg_service.dart';
import 'package:beading/domain/easter_eggs/long_session_watcher.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/grid_progress_store.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/image_pattern/image_pattern_repository.dart';
import 'package:beading/domain/image_pattern/use_cases/import_book_pattern.dart';
import 'package:beading/domain/projects/use_cases/delete_project.dart';
import 'package:beading/domain/projects/use_cases/duplicate_project.dart';
import 'package:beading/domain/settings/app_events_secret_tap_handler.dart';
import 'package:beading/domain/settings/app_info.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:beading/domain/settings/keep_screen_awake_setting.dart';
import 'package:beading/domain/settings/reduce_transparency_source.dart';
import 'package:beading/domain/settings/screen_wake_lock.dart';
import 'package:beading/domain/settings/secret_tap_handler.dart';
import 'package:beading/domain/settings/settings_repository.dart';
import 'package:beading/domain/settings/wakelock_controller.dart';
import 'package:beading/presentation/settings/settings_cubit.dart';
import 'package:beading/presentation/theme/theme_mode_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../support/in_memory_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('configureDependencies регистрирует базовые сервисы', () async {
    final GetIt locator = GetIt.asNewInstance();

    await configureDependencies(locator: locator, database: createInMemoryDatabase());

    expect(locator<Clock>(), isA<SystemClock>());
    expect(locator<IdGenerator>(), isA<UuidV7IdGenerator>());
    expect(locator<SettingsRepository>(), isA<DriftSettingsRepository>());
    expect(locator<DeviceIdProvider>(), isA<DriftDeviceIdProvider>());
    expect(locator<OrientationLock>(), isA<SystemChromeOrientationLock>());
    expect(locator<DesktopWindow>(), isA<WindowManagerDesktopWindow>());
    expect(locator<ScreenWakeLock>(), isA<WakelockPlusScreenWakeLock>());
    expect(locator<KeepScreenAwakeSetting>(), isA<RepositoryKeepScreenAwakeSetting>());
    expect(locator<ReduceTransparencySource>(), isA<MethodChannelReduceTransparencySource>());
    expect(locator<WakelockController>(), isNotNull);
    expect(locator<ThemeModeCubit>(), isA<ThemeModeCubit>());
    expect(locator<SettingsCubit>(), isA<SettingsCubit>());
    expect(locator<AppInfoProvider>(), isA<PackageInfoAppInfoProvider>());
    expect(locator<SecretTapHandler>(), isA<AppEventsSecretTapHandler>());
    expect(locator<EasterEggLog>(), isA<DriftEasterEggLog>());
    expect(locator<ComplimentSource>(), isA<AssetComplimentSource>());
    expect(locator<EasterEggService>(), same(locator<EasterEggService>()));
    expect(locator<LongSessionWatcher>(), isA<LongSessionWatcher>());
    expect(locator<ImagePatternRepository>(), isA<DriftImagePatternRepository>());
    expect(locator<GridPatternRepository>(), isA<DriftGridPatternRepository>());
    expect(locator<GridProgressStore>(), isA<DriftGridProgressStore>());
    expect(locator<CreateGridPattern>(), isA<CreateGridPattern>());
    expect(locator<ImportBookPattern>(), isA<ImportBookPattern>());
    expect(locator<DeleteProject>(), isA<DeleteProject>());
    expect(locator<DuplicateProject>(), isA<DuplicateProject>());
  });

  test('повторная настройка не падает и пересоздаёт регистрации', () async {
    final GetIt locator = GetIt.asNewInstance();

    await configureDependencies(locator: locator, database: createInMemoryDatabase());
    await configureDependencies(locator: locator, database: createInMemoryDatabase());

    expect(locator.isRegistered<Clock>(), isTrue);
  });
}
