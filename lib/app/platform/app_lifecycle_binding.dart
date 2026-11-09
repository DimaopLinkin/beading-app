import 'package:beading/domain/settings/wakelock_controller.dart';
import 'package:flutter/widgets.dart';

/// Передаёт жизненный цикл приложения в [WakelockController].
class AppLifecycleBinding {
  AppLifecycleBinding(this._controller) {
    _listener = AppLifecycleListener(onStateChange: onStateChanged);
  }

  final WakelockController _controller;
  late final AppLifecycleListener _listener;

  /// `inactive` (шторка, входящий звонок) не считаем уходом в фон.
  Future<void> onStateChanged(AppLifecycleState state) => switch (state) {
    AppLifecycleState.resumed || AppLifecycleState.inactive => _controller.onResumed(),
    AppLifecycleState.hidden || AppLifecycleState.paused || AppLifecycleState.detached => _controller.onPaused(),
  };

  void dispose() => _listener.dispose();
}
