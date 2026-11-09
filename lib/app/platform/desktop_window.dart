import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Параметры окна macOS: «портретное» окно, как на телефоне.
class DesktopWindowConfig {
  const DesktopWindowConfig({
    this.size = const Size(480, 900),
    this.minimumSize = const Size(400, 700),
    this.hiddenTitleBar = true,
  });

  final Size size;
  final Size minimumSize;

  /// Скрытая полоса заголовка, контент на всё окно, системные кнопки остаются.
  final bool hiddenTitleBar;
}

abstract interface class DesktopWindow {
  Future<void> configure(DesktopWindowConfig config);
}

/// Реализация на `window_manager`; вне macOS ничего не делает.
class WindowManagerDesktopWindow implements DesktopWindow {
  WindowManagerDesktopWindow({TargetPlatform? platform}) : _platform = platform ?? defaultTargetPlatform;

  final TargetPlatform _platform;

  @override
  Future<void> configure(DesktopWindowConfig config) async {
    if (_platform != TargetPlatform.macOS) {
      return;
    }
    await windowManager.ensureInitialized();
    final WindowOptions options = WindowOptions(
      size: config.size,
      minimumSize: config.minimumSize,
      center: true,
      titleBarStyle: config.hiddenTitleBar ? TitleBarStyle.hidden : TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
}
