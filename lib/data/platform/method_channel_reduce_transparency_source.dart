import 'dart:async';

import 'package:beading/domain/settings/reduce_transparency_source.dart';
import 'package:flutter/services.dart';

/// Читает «Уменьшить прозрачность» через платформенный канал `app.beading/accessibility`.
///
/// Dart → платформа: `isReduceTransparencyEnabled` → `bool`.
/// Платформа → Dart: `reduceTransparencyChanged` с `bool` при смене настройки.
/// Нативная часть: `ios/Runner/AppDelegate.swift` и `macos/Runner/AppDelegate.swift`.
class MethodChannelReduceTransparencySource implements ReduceTransparencySource {
  MethodChannelReduceTransparencySource({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(name) {
    _channel.setMethodCallHandler(_onCall);
  }

  static const String name = 'app.beading/accessibility';
  static const String getMethod = 'isReduceTransparencyEnabled';
  static const String changedMethod = 'reduceTransparencyChanged';

  final MethodChannel _channel;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Future<bool> current() async {
    try {
      return await _channel.invokeMethod<bool>(getMethod) ?? false;
    } on MissingPluginException {
      // Платформа без нативной части (тесты, не iOS и не macOS): стекло остаётся прозрачным.
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method == changedMethod && call.arguments is bool) {
      _changes.add(call.arguments as bool);
    }
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _changes.close();
  }
}
