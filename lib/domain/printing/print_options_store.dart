import 'package:beading/domain/printing/print_options.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/settings_repository.dart';

/// Запоминает настройки печати между сборками PDF.
final class PrintOptionsStore {
  const PrintOptionsStore(this._settings);

  final SettingsRepository _settings;

  Future<PrintOptions> load() async =>
      PrintOptions.decode((await _settings.read<String>(SettingKeys.printOptions)).valueOrNull);

  Future<void> save(PrintOptions options) async {
    await _settings.write<String>(SettingKeys.printOptions, options.encode());
  }
}
