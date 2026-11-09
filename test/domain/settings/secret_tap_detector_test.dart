import 'package:beading/domain/settings/secret_tap_detector.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';

void main() {
  late FakeClock clock;
  late SecretTapDetector detector;

  setUp(() {
    clock = FakeClock(DateTime(2026, 11, 9));
    detector = SecretTapDetector(clock: clock);
  });

  test('седьмое нажатие подряд срабатывает, шесть — нет', () {
    for (var i = 0; i < 6; i++) {
      expect(detector.register(), isFalse);
      clock.advance(const Duration(milliseconds: 300));
    }
    expect(detector.register(), isTrue);
  });

  test('пауза дольше окна сбрасывает серию', () {
    for (var i = 0; i < 6; i++) {
      detector.register();
      clock.advance(const Duration(milliseconds: 300));
    }
    clock.advance(const Duration(seconds: 3));
    expect(detector.register(), isFalse);
  });

  test('после срабатывания счёт идёт заново', () {
    for (var i = 0; i < 7; i++) {
      detector.register();
    }
    for (var i = 0; i < 6; i++) {
      expect(detector.register(), isFalse);
    }
    expect(detector.register(), isTrue);
  });
}
