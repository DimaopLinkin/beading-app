import 'dart:async';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:beading/domain/settings/setting_key.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/settings_repository.dart';

/// Фейк настроек для тестов: хранит значения в памяти и считает записи.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({AppThemeMode themeMode = AppThemeMode.system}) {
    values[SettingKeys.themeMode.name] = themeMode;
  }

  final Map<String, Object?> values = <String, Object?>{};
  int saveCount = 0;

  /// Если `true`, записи возвращают ошибку хранилища.
  bool failWrites = false;

  AppThemeMode get themeMode => _valueOf(SettingKeys.themeMode);

  @override
  Future<Result<T>> read<T>(SettingKey<T> key) async => Success<T>(_valueOf(key));

  @override
  Future<Result<void>> write<T>(SettingKey<T> key, T value) async {
    if (failWrites) return const Err<void>(StorageFailure('boom'));
    saveCount++;
    values[key.name] = value;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> reset<T>(SettingKey<T> key) async {
    values.remove(key.name);
    return const Success<void>(null);
  }

  @override
  Stream<T> watch<T>(SettingKey<T> key) => Stream<T>.value(_valueOf(key));

  T _valueOf<T>(SettingKey<T> key) => (values[key.name] as T?) ?? key.defaultValue;
}
