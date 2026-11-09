import 'package:beading/app/di.dart';
import 'package:beading/app/platform/desktop_window.dart';
import 'package:beading/app/platform/orientation_lock.dart';
import 'package:beading/core/clock.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/data/platform/wakelock_plus_screen_wake_lock.dart';
import 'package:beading/data/settings/in_memory_keep_screen_awake_setting.dart';
import 'package:beading/domain/settings/keep_screen_awake_setting.dart';
import 'package:beading/domain/settings/screen_wake_lock.dart';
import 'package:beading/domain/settings/wakelock_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  test('configureDependencies регистрирует базовые сервисы', () async {
    final GetIt locator = GetIt.asNewInstance();

    await configureDependencies(locator);

    expect(locator<Clock>(), isA<SystemClock>());
    expect(locator<IdGenerator>(), isA<UuidV7IdGenerator>());
    expect(locator<OrientationLock>(), isA<SystemChromeOrientationLock>());
    expect(locator<DesktopWindow>(), isA<WindowManagerDesktopWindow>());
    expect(locator<ScreenWakeLock>(), isA<WakelockPlusScreenWakeLock>());
    expect(locator<KeepScreenAwakeSetting>(), isA<InMemoryKeepScreenAwakeSetting>());
    expect(locator<WakelockController>(), isNotNull);
  });

  test('повторная настройка не падает и пересоздаёт регистрации', () async {
    final GetIt locator = GetIt.asNewInstance();

    await configureDependencies(locator);
    await configureDependencies(locator);

    expect(locator.isRegistered<Clock>(), isTrue);
  });
}
