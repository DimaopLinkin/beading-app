import 'package:beading/domain/settings/keep_screen_awake_setting.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/settings_repository.dart';

/// Настройка «Не гасить экран» поверх [SettingsRepository].
class RepositoryKeepScreenAwakeSetting implements KeepScreenAwakeSetting {
  const RepositoryKeepScreenAwakeSetting(this._settings);

  final SettingsRepository _settings;

  @override
  Future<bool> read() async =>
      (await _settings.read(SettingKeys.keepScreenAwake)).valueOrNull ?? SettingKeys.keepScreenAwake.defaultValue;

  /// Ошибки хранилища гасим: сбой настройки не должен ронять приложение, экран просто остаётся как был.
  @override
  Stream<bool> watch() => _settings.watch(SettingKeys.keepScreenAwake).handleError((Object _) {});
}
