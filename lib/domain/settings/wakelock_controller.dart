import 'dart:async';

import 'package:beading/domain/settings/keep_screen_awake_setting.dart';
import 'package:beading/domain/settings/screen_wake_lock.dart';

/// Держит экран включённым, пока приложение на переднем плане и настройка включена.
class WakelockController {
  WakelockController({required ScreenWakeLock wakeLock, required KeepScreenAwakeSetting setting})
    : _wakeLock = wakeLock,
      _setting = setting;

  final ScreenWakeLock _wakeLock;
  final KeepScreenAwakeSetting _setting;

  StreamSubscription<bool>? _subscription;
  bool _foreground = true;
  bool _enabledBySetting = true;
  bool _locked = false;
  Future<void> _queue = Future<void>.value();

  /// Читает настройку, подписывается на её изменения и применяет состояние для переднего плана.
  Future<void> start() async {
    _enabledBySetting = await _setting.read();
    _subscription = _setting.watch().listen((value) {
      _enabledBySetting = value;
      unawaited(_apply());
    });
    _foreground = true;
    await _apply();
  }

  Future<void> onResumed() {
    _foreground = true;
    return _apply();
  }

  Future<void> onPaused() {
    _foreground = false;
    return _apply();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _foreground = false;
    await _apply();
  }

  /// Применяет нужное состояние; вызовы идут строго по очереди, чтобы enable/disable не перепутались.
  Future<void> _apply() {
    return _queue = _queue.then((_) async {
      final bool wanted = _foreground && _enabledBySetting;
      if (wanted == _locked) {
        return;
      }
      try {
        await (wanted ? _wakeLock.enable() : _wakeLock.disable());
        _locked = wanted;
      } on Exception {
        // Сбой платформы не должен ронять приложение: экран просто может погаснуть.
      }
    });
  }
}
