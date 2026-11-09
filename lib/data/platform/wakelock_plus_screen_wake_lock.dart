import 'package:beading/domain/settings/screen_wake_lock.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class WakelockPlusScreenWakeLock implements ScreenWakeLock {
  const WakelockPlusScreenWakeLock();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}
