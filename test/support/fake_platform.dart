import 'dart:async';

import 'package:beading/app/platform/desktop_window.dart';
import 'package:beading/app/platform/orientation_lock.dart';
import 'package:beading/domain/settings/keep_screen_awake_setting.dart';
import 'package:beading/domain/settings/reduce_transparency_source.dart';
import 'package:beading/domain/settings/screen_wake_lock.dart';
import 'package:beading/domain/settings/wakelock_controller.dart';

class FakeScreenWakeLock implements ScreenWakeLock {
  final List<String> calls = <String>[];
  bool failing = false;

  bool get locked => calls.isNotEmpty && calls.last == 'enable';

  @override
  Future<void> enable() async {
    if (failing) {
      throw Exception('boom');
    }
    calls.add('enable');
  }

  @override
  Future<void> disable() async {
    if (failing) {
      throw Exception('boom');
    }
    calls.add('disable');
  }
}

class FakeKeepScreenAwakeSetting implements KeepScreenAwakeSetting {
  FakeKeepScreenAwakeSetting({this.value = true});

  bool value;
  final StreamController<bool> controller = StreamController<bool>.broadcast();

  @override
  Future<bool> read() async => value;

  @override
  Stream<bool> watch() => controller.stream;

  void change({required bool to}) {
    value = to;
    controller.add(to);
  }
}

class FakeOrientationLock implements OrientationLock {
  int portraitCalls = 0;

  @override
  Future<void> lockPortrait() async => portraitCalls++;
}

class FakeDesktopWindow implements DesktopWindow {
  final List<DesktopWindowConfig> configs = <DesktopWindowConfig>[];

  @override
  Future<void> configure(DesktopWindowConfig config) async => configs.add(config);
}

WakelockController fakeWakelockController([FakeScreenWakeLock? lock, FakeKeepScreenAwakeSetting? setting]) =>
    WakelockController(wakeLock: lock ?? FakeScreenWakeLock(), setting: setting ?? FakeKeepScreenAwakeSetting());

class FakeReduceTransparencySource implements ReduceTransparencySource {
  FakeReduceTransparencySource({this.initial = false});

  bool initial;
  final StreamController<bool> controller = StreamController<bool>.broadcast();

  @override
  Future<bool> current() async => initial;

  @override
  Stream<bool> get changes => controller.stream;

  Future<void> dispose() => controller.close();
}
