import 'package:flutter/services.dart';

/// Фиксирует ориентацию экрана (MUST-G1).
abstract interface class OrientationLock {
  Future<void> lockPortrait();
}

class SystemChromeOrientationLock implements OrientationLock {
  const SystemChromeOrientationLock();

  @override
  Future<void> lockPortrait() => SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
}
