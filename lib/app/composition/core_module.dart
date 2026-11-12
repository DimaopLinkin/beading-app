import 'package:beading/app/platform/desktop_window.dart';
import 'package:beading/app/platform/orientation_lock.dart';
import 'package:beading/core/clock.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/image_pattern/local_file_store.dart';
import 'package:beading/data/platform/method_channel_reduce_transparency_source.dart';
import 'package:beading/data/platform/wakelock_plus_screen_wake_lock.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/data/settings/drift_settings_repository.dart';
import 'package:beading/data/settings/repository_keep_screen_awake_setting.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:beading/domain/settings/keep_screen_awake_setting.dart';
import 'package:beading/domain/settings/reduce_transparency_source.dart';
import 'package:beading/domain/settings/screen_wake_lock.dart';
import 'package:beading/domain/settings/settings_repository.dart';
import 'package:beading/domain/settings/wakelock_controller.dart';

/// Ядро графа зависимостей (ADR-0007): база, время, идентификаторы, настройки, события, файлы и платформенные адаптеры.
///
/// Всё живёт всё время работы приложения и создаётся при первом обращении. Необязательные параметры конструктора
/// подменяют объекты в тестах.
final class CoreModule {
  CoreModule({
    required this.database,
    Clock? clock,
    FileStore? fileStore,
    OrientationLock? orientationLock,
    DesktopWindow? desktopWindow,
    ScreenWakeLock? screenWakeLock,
    ReduceTransparencySource? reduceTransparency,
  }) : _clock = clock,
       _fileStore = fileStore,
       _orientationLock = orientationLock,
       _desktopWindow = desktopWindow,
       _screenWakeLock = screenWakeLock,
       _reduceTransparency = reduceTransparency;

  final AppDatabase database;
  final Clock? _clock;
  final FileStore? _fileStore;
  final OrientationLock? _orientationLock;
  final DesktopWindow? _desktopWindow;
  final ScreenWakeLock? _screenWakeLock;
  final ReduceTransparencySource? _reduceTransparency;

  late final Clock clock = _clock ?? const SystemClock();

  late final IdGenerator ids = UuidV7IdGenerator(clock: clock);

  late final DeviceIdProvider deviceIds = DriftDeviceIdProvider(dao: database.settingsDao, ids: ids, clock: clock);

  late final SettingsRepository settings = DriftSettingsRepository(
    dao: database.settingsDao,
    deviceIds: deviceIds,
    clock: clock,
  );

  late final AppEvents events = BroadcastAppEvents();

  late final FileStore fileStore = _fileStore ?? LocalFileStore.applicationSupport();

  late final OrientationLock orientationLock = _orientationLock ?? const SystemChromeOrientationLock();

  late final DesktopWindow desktopWindow = _desktopWindow ?? WindowManagerDesktopWindow();

  late final ScreenWakeLock screenWakeLock = _screenWakeLock ?? const WakelockPlusScreenWakeLock();

  late final ReduceTransparencySource reduceTransparency =
      _reduceTransparency ?? MethodChannelReduceTransparencySource();

  late final KeepScreenAwakeSetting keepScreenAwake = RepositoryKeepScreenAwakeSetting(settings);

  late final WakelockController wakelock = WakelockController(wakeLock: screenWakeLock, setting: keepScreenAwake);

  /// Закрывает объекты ядра. Только то, что создано: нетронутые `late final` не инициализируются.
  Future<void> dispose() async {
    if (_reduceTransparency == null) {
      final ReduceTransparencySource source = reduceTransparency;
      if (source is MethodChannelReduceTransparencySource) {
        await source.dispose();
      }
    }
    final AppEvents e = events;
    if (e is BroadcastAppEvents) {
      await e.dispose();
    }
    await database.close();
  }
}
