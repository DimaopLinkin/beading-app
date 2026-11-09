import 'package:beading/domain/easter_eggs/easter_egg_policy.dart';
import 'package:beading/domain/easter_eggs/long_session_watcher.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';

void main() {
  test('через 90 минут шлёт LongSession ровно один раз', () {
    fakeAsync((async) {
      final FakeClock clock = FakeClock(DateTime(2026, 11, 9, 12));
      final BroadcastAppEvents events = BroadcastAppEvents();
      final List<AppEvent> received = <AppEvent>[];
      events.stream.listen(received.add);
      final LongSessionWatcher watcher = LongSessionWatcher(events: events, clock: clock)..start();

      for (int minute = 0; minute < 200; minute++) {
        async.elapse(const Duration(minutes: 1));
        clock.advance(const Duration(minutes: 1));
        async.flushMicrotasks();
        if (minute == 88) {
          expect(received, isEmpty, reason: '89 минут — ещё рано');
        }
      }

      expect(received, <AppEvent>[const LongSession()]);
      watcher.dispose();
    });
  });

  test('ровно 90 минут ещё не «дольше 90»', () {
    fakeAsync((async) {
      final FakeClock clock = FakeClock(DateTime(2026, 11, 9, 12));
      final BroadcastAppEvents events = BroadcastAppEvents();
      final List<AppEvent> received = <AppEvent>[];
      events.stream.listen(received.add);
      LongSessionWatcher(events: events, clock: clock).start();

      clock.advance(EasterEggPolicy.longSession);
      async.elapse(const Duration(minutes: 1));
      async.flushMicrotasks();

      // Проверка на тике: now - start == 90 минут + 0, а тик был раньше порога.
      expect(received, isEmpty);
    });
  });

  test('dispose останавливает проверки', () {
    fakeAsync((async) {
      final FakeClock clock = FakeClock(DateTime(2026, 11, 9, 12));
      final BroadcastAppEvents events = BroadcastAppEvents();
      final List<AppEvent> received = <AppEvent>[];
      events.stream.listen(received.add);
      LongSessionWatcher(events: events, clock: clock)
        ..start()
        ..dispose();

      clock.advance(const Duration(hours: 3));
      async.elapse(const Duration(hours: 3));
      async.flushMicrotasks();

      expect(received, isEmpty);
    });
  });
}
