import 'package:beading/domain/printing/print_options.dart';
import 'package:beading/domain/settings/setting_key.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/settings_repository.dart';

/// Запоминает настройки печати. Формат листа общий, а число мест на стойке хранится в каждой вышивке отдельно
/// (T83): номера цветов совпадают в PDF, окне «Нитки» и списке «Что осталось по цветам».
final class PrintOptionsStore {
  const PrintOptionsStore(this._settings);

  final SettingsRepository _settings;

  /// Ключ числа мест на стойке для вышивки [projectId].
  static SettingKey<int> slotsKey(String projectId) => SettingKey<int>(
    name: 'printSlots.$projectId',
    defaultValue: 0, // 0 — для этой вышивки места не задавали
    encode: (value) => '$value',
    decode: int.tryParse,
  );

  /// Без [projectId] (схема в мастере ещё не сохранена) — общие настройки; иначе места берутся из вышивки, если
  /// их для неё уже задавали.
  Future<PrintOptions> load({String? projectId}) async {
    final PrintOptions shared = PrintOptions.decode(
      (await _settings.read<String>(SettingKeys.printOptions)).valueOrNull,
    );
    if (projectId == null) return shared;
    final int own = (await _settings.read<int>(slotsKey(projectId))).valueOrNull ?? 0;
    return own == 0 ? shared : shared.copyWith(slotsPerRack: own.clamp(PrintOptions.minSlots, PrintOptions.maxSlots));
  }

  /// Формат и места запоминаются как общие настройки; с [projectId] места закрепляются и за вышивкой.
  Future<void> save(PrintOptions options, {String? projectId}) async {
    await _settings.write<String>(SettingKeys.printOptions, options.encode());
    if (projectId != null) await _settings.write<int>(slotsKey(projectId), options.slotsPerRack);
  }
}
