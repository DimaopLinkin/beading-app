import 'package:beading/core/clock.dart';

/// Управляемые часы для тестов: время двигается только вручную.
class FakeClock implements Clock {
  FakeClock(DateTime start) : _now = start;

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) => _now = _now.add(duration);

  void set(DateTime value) => _now = value;
}
