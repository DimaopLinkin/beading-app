import 'package:beading/domain/settings/wakelock_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_platform.dart';

void main() {
  late FakeScreenWakeLock lock;
  late FakeKeepScreenAwakeSetting setting;
  late WakelockController controller;

  setUp(() {
    lock = FakeScreenWakeLock();
    setting = FakeKeepScreenAwakeSetting();
    controller = WakelockController(wakeLock: lock, setting: setting);
  });

  tearDown(() => controller.dispose());

  test('при старте с включённой настройкой экран не гаснет', () async {
    await controller.start();

    expect(lock.calls, <String>['enable']);
  });

  test('при старте с выключенной настройкой экран не трогаем', () async {
    setting.value = false;

    await controller.start();

    expect(lock.calls, isEmpty);
  });

  test('уход в фон отпускает экран, возврат — снова держит', () async {
    await controller.start();

    await controller.onPaused();
    expect(lock.calls, <String>['enable', 'disable']);

    await controller.onResumed();
    expect(lock.calls, <String>['enable', 'disable', 'enable']);
  });

  test('повторные события без смены состояния не дёргают платформу', () async {
    await controller.start();

    await controller.onResumed();
    await controller.onResumed();

    expect(lock.calls, <String>['enable']);
  });

  test('при выключенной настройке возврат на передний план экран не держит', () async {
    setting.value = false;
    await controller.start();

    await controller.onPaused();
    await controller.onResumed();

    expect(lock.calls, isEmpty);
  });

  test('выключение настройки на переднем плане отпускает экран, включение — держит', () async {
    await controller.start();

    setting.change(to: false);
    await pumpEventQueue();
    expect(lock.calls, <String>['enable', 'disable']);

    setting.change(to: true);
    await pumpEventQueue();
    expect(lock.calls, <String>['enable', 'disable', 'enable']);
  });

  test('включение настройки в фоне экран не захватывает', () async {
    setting.value = false;
    await controller.start();
    await controller.onPaused();

    setting.change(to: true);
    await pumpEventQueue();

    expect(lock.calls, isEmpty);
  });

  test('сбой платформы не пробрасывается и состояние пробуется снова', () async {
    lock.failing = true;
    await controller.start();
    expect(lock.calls, isEmpty);

    lock.failing = false;
    await controller.onResumed();
    expect(lock.calls, <String>['enable']);
  });

  test('dispose отпускает экран и отписывается от настройки', () async {
    await controller.start();

    await controller.dispose();
    expect(lock.calls, <String>['enable', 'disable']);

    setting.change(to: true);
    await pumpEventQueue();
    expect(lock.calls, <String>['enable', 'disable']);
  });
}
