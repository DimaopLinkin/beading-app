import 'dart:async';

import 'package:beading/core/clock.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/easter_eggs/easter_egg_policy.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/weaving/work_session.dart';
import 'package:beading/domain/weaving/work_session_repository.dart';

/// Считает время плетения: сессия идёт, пока экран открыт и приложение на виду.
///
/// - [start] начинает сессию, [pause] (уход в фон) закрывает её, [resume] начинает новую, [stop] закрывает и выходит.
/// - Раз в [heartbeat] конец сессии подтягивается к «сейчас»: вылет приложения теряет не больше этого промежутка.
/// - Непрерывная сессия дольше [EasterEggPolicy.longSession] один раз шлёт [LongSession].
class WorkSessionTracker {
  WorkSessionTracker({
    required WorkSessionRepository sessions,
    required Clock clock,
    required AppEvents events,
    this.heartbeat = const Duration(seconds: 30),
    this.longSession = EasterEggPolicy.longSession,
  }) : _sessions = sessions,
       _clock = clock,
       _events = events;

  final WorkSessionRepository _sessions;
  final Clock _clock;
  final AppEvents _events;
  final Duration heartbeat;
  final Duration longSession;

  String? _projectId;
  WorkSession? _current;
  Timer? _timer;
  bool _paused = false;
  bool _longSent = false;
  DateTime? _runStart;

  /// Идёт ли сессия сейчас.
  bool get isRunning => _current != null;

  /// Начинает учёт для [projectId]. Повторный вызов для того же проекта ничего не меняет.
  Future<void> start(String projectId) async {
    if (_projectId == projectId) {
      return;
    }
    await stop();
    _projectId = projectId;
    _paused = false;
    await _begin();
  }

  /// Приложение ушло в фон: сессия закрывается.
  Future<void> pause() async {
    if (_projectId == null || _paused) {
      return;
    }
    _paused = true;
    await _end();
  }

  /// Приложение вернулось: начинается новая сессия.
  Future<void> resume() async {
    if (_projectId == null || !_paused) {
      return;
    }
    _paused = false;
    await _begin();
  }

  /// Выход с экрана.
  Future<void> stop() async {
    await _end();
    _projectId = null;
    _paused = false;
  }

  Future<void> _begin() async {
    final String? projectId = _projectId;
    if (projectId == null) {
      return;
    }
    final DateTime now = _clock.now();
    _runStart = now;
    _longSent = false;
    final Result<WorkSession> started = await _sessions.start(projectId, now);
    // За время записи экран могли закрыть.
    if (_projectId != projectId || _paused) {
      if (started case Success<WorkSession>(:final WorkSession value)) {
        await _sessions.touch(value.id, _clock.now());
      }
      return;
    }
    if (started case Success<WorkSession>(:final WorkSession value)) {
      _current = value;
      _timer = Timer.periodic(heartbeat, (_) => unawaited(_beat()));
    }
  }

  Future<void> _beat() async {
    final WorkSession? session = _current;
    if (session == null) {
      return;
    }
    final DateTime now = _clock.now();
    await _sessions.touch(session.id, now);
    final DateTime? began = _runStart;
    if (!_longSent && began != null && now.difference(began) >= longSession) {
      _longSent = true;
      _events.publish(const LongSession());
    }
  }

  Future<void> _end() async {
    _timer?.cancel();
    _timer = null;
    final WorkSession? session = _current;
    _current = null;
    if (session != null) {
      await _sessions.touch(session.id, _clock.now());
    }
  }
}
