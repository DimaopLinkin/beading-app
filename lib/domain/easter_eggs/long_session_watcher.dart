import 'dart:async';

import 'package:beading/core/clock.dart';
import 'package:beading/domain/easter_eggs/app_event.dart';
import 'package:beading/domain/easter_eggs/app_events.dart';
import 'package:beading/domain/easter_eggs/easter_egg_policy.dart';

/// Шлёт [LongSession], когда сессия идёт дольше [EasterEggPolicy.longSession]. Один раз за сессию.
class LongSessionWatcher {
  LongSessionWatcher({required AppEvents events, required Clock clock, Duration checkEvery = const Duration(minutes: 1)})
    : _events = events,
      _clock = clock,
      _checkEvery = checkEvery;

  final AppEvents _events;
  final Clock _clock;
  final Duration _checkEvery;

  Timer? _timer;

  /// Начало сессии — момент вызова.
  void start() {
    if (_timer != null) {
      return;
    }
    final DateTime started = _clock.now();
    _timer = Timer.periodic(_checkEvery, (timer) {
      if (_clock.now().difference(started) > EasterEggPolicy.longSession) {
        timer.cancel();
        _events.add(const LongSession());
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
