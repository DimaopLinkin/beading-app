import 'dart:async';

import 'package:beading/domain/settings/keep_screen_awake_setting.dart';

/// Временное хранилище настройки в памяти (до T03). По умолчанию включено.
class InMemoryKeepScreenAwakeSetting implements KeepScreenAwakeSetting {
  InMemoryKeepScreenAwakeSetting({bool initial = true}) : _value = initial;

  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  bool _value;

  @override
  Future<bool> read() async => _value;

  @override
  Stream<bool> watch() => _changes.stream;

  Future<void> write({required bool value}) async {
    _value = value;
    _changes.add(value);
  }
}
