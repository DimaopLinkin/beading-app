import 'package:beading/core/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_clock.dart';

void main() {
  test('SystemClock возвращает текущее время', () {
    final DateTime before = DateTime.now();
    final DateTime value = const SystemClock().now();
    final DateTime after = DateTime.now();

    expect(value.isBefore(before), isFalse);
    expect(value.isAfter(after), isFalse);
  });

  test('FakeClock стоит на месте и двигается вручную', () {
    final FakeClock clock = FakeClock(DateTime.utc(2026));

    expect(clock.now(), DateTime.utc(2026));
    clock.advance(const Duration(hours: 1));
    expect(clock.now(), DateTime.utc(2026, 1, 1, 1));
    clock.set(DateTime.utc(2027));
    expect(clock.now(), DateTime.utc(2027));
  });
}
