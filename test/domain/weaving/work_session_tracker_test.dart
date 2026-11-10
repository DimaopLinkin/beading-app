import 'package:beading/domain/weaving/work_session.dart';
import 'package:beading/domain/weaving/work_session_tracker.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_work_sessions.dart';

void main() {
  late FakeWorkSessionRepository sessions;
  late FakeClock clock;

  setUp(() {
    sessions = FakeWorkSessionRepository();
    clock = FakeClock(DateTime.utc(2026, 11, 10, 9));
  });

  WorkSessionTracker tracker() =>
      WorkSessionTracker(sessions: sessions, clock: clock, heartbeat: const Duration(minutes: 1));

  /// Двигает и часы, и таймеры: тик таймера читает время из [clock].
  void elapse(FakeAsync async, Duration d) {
    clock.advance(d);
    async.elapse(d);
  }

  test('start открывает сессию, повторный start того же проекта ничего не меняет', () {
    fakeAsync((async) {
      final WorkSessionTracker t = tracker();
      t.start('p1');
      async.flushMicrotasks();
      t.start('p1');
      async.flushMicrotasks();
      expect(sessions.sessions, hasLength(1));
      expect(t.isRunning, isTrue);
      t.stop();
      async.flushMicrotasks();
    });
  });

  test('раз в минуту конец сессии подтягивается к «сейчас»', () {
    fakeAsync((async) {
      final WorkSessionTracker t = tracker();
      t.start('p1');
      async.flushMicrotasks();
      elapse(async, const Duration(minutes: 3));
      async.flushMicrotasks();
      expect(sessions.sessions['ws-1']!.duration, const Duration(minutes: 3));
      t.stop();
      async.flushMicrotasks();
    });
  });

  test('stop закрывает сессию в момент выхода', () {
    fakeAsync((async) {
      final WorkSessionTracker t = tracker();
      t.start('p1');
      async.flushMicrotasks();
      clock.advance(const Duration(seconds: 90));
      t.stop();
      async.flushMicrotasks();
      expect(sessions.sessions['ws-1']!.duration, const Duration(seconds: 90));
      expect(t.isRunning, isFalse);
    });
  });

  test('уход в фон закрывает сессию, возвращение начинает новую; время в фоне не считается', () {
    fakeAsync((async) {
      final WorkSessionTracker t = tracker();
      t.start('p1');
      async.flushMicrotasks();
      elapse(async, const Duration(minutes: 5));
      t.pause();
      async.flushMicrotasks();
      t.pause(); // повторная пауза безвредна
      async.flushMicrotasks();
      elapse(async, const Duration(minutes: 30));
      t.resume();
      async.flushMicrotasks();
      t.resume(); // повторное возвращение безвредно
      async.flushMicrotasks();
      elapse(async, const Duration(minutes: 2));
      t.stop();
      async.flushMicrotasks();

      final List<WorkSession> all = sessions.sessions.values.toList();
      expect(all, hasLength(2));
      expect(all[0].duration, const Duration(minutes: 5));
      expect(all[1].duration, const Duration(minutes: 2));
    });
  });

  test('pause и resume без start ничего не делают', () {
    fakeAsync((async) {
      final WorkSessionTracker t = tracker();
      t.pause();
      t.resume();
      async.flushMicrotasks();
      expect(sessions.sessions, isEmpty);
    });
  });

  test('другой проект: прежняя сессия закрывается, начинается новая', () {
    fakeAsync((async) {
      final WorkSessionTracker t = tracker();
      t.start('p1');
      async.flushMicrotasks();
      elapse(async, const Duration(minutes: 1));
      t.start('p2');
      async.flushMicrotasks();
      expect(sessions.sessions['ws-1']!.duration, const Duration(minutes: 1));
      expect(sessions.sessions['ws-2']!.projectId, 'p2');
      t.stop();
      async.flushMicrotasks();
    });
  });

  test('сбой записи начала: учёта нет, но экран работает', () {
    fakeAsync((async) {
      sessions.failStart = true;
      final WorkSessionTracker t = tracker();
      t.start('p1');
      async.flushMicrotasks();
      expect(t.isRunning, isFalse);
      elapse(async, const Duration(minutes: 2));
      t.stop();
      async.flushMicrotasks();
      expect(sessions.sessions, isEmpty);
    });
  });
}
