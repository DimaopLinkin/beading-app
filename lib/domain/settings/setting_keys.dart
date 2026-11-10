import 'dart:convert';

import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:beading/domain/settings/setting_key.dart';
import 'package:beading/domain/settings/special_date.dart';

/// Самое длинное имя для комплиментов `{name}`: текст комплимента целиком не длиннее 70 символов.
const int userNameMaxLength = 70;

/// Все настройки приложения. Новая настройка — новая константа здесь, без миграции БД.
abstract final class SettingKeys {
  static const SettingKey<AppThemeMode> themeMode = SettingKey<AppThemeMode>(
    name: 'themeMode',
    defaultValue: AppThemeMode.system,
    encode: _encodeEnum,
    decode: _decodeThemeMode,
  );

  /// Не гасить экран во время работы (по умолчанию включено).
  static const SettingKey<bool> keepScreenAwake = SettingKey<bool>(
    name: 'keepScreenAwake',
    defaultValue: true,
    encode: _encodeBool,
    decode: _decodeBool,
  );

  /// Режим символов на схеме по умолчанию.
  static const SettingKey<bool> symbolMode = SettingKey<bool>(
    name: 'symbolMode',
    defaultValue: false,
    encode: _encodeBool,
    decode: _decodeBool,
  );

  /// Производитель бисера по умолчанию (значение каталога `catalog_colors.brand`).
  ///
  /// Совпадает с брендом из `assets/catalog` (проверяет `bundled_catalog_test`).
  static const SettingKey<String> defaultBeadBrand = SettingKey<String>(
    name: 'defaultBeadBrand',
    defaultValue: 'Miyuki',
    encode: _identity,
    decode: _identity,
  );

  /// Производитель мулине по умолчанию (значение каталога `catalog_colors.brand`). Отдельно от бисера: ADR-0003.
  ///
  /// Строка-заглушка: T36 (каталог мулине) сверит её с `catalog_colors.brand`.
  static const SettingKey<String> defaultFlossBrand = SettingKey<String>(
    name: 'defaultFlossBrand',
    defaultValue: 'DMC',
    encode: _identity,
    decode: _identity,
  );

  /// Имя пользовательницы в текстах комплиментов (`{name}`).
  static const SettingKey<String> userName = SettingKey<String>(
    name: 'userName',
    defaultValue: 'Настя',
    encode: _identity,
    decode: _identity,
  );

  /// Особые даты для пасхалок. По умолчанию пусто: даты в код не зашиваем.
  static const SettingKey<List<SpecialDate>> specialDates = SettingKey<List<SpecialDate>>(
    name: 'specialDates',
    defaultValue: <SpecialDate>[],
    encode: _encodeSpecialDates,
    decode: _decodeSpecialDates,
  );

  /// Сколько рядов отмечено на этом устройстве за всё время: по нему приходит `RowsCompleted` для пасхалок.
  /// Локальная: счётчики двух устройств в синхронизацию не складываем.
  static const SettingKey<int> rowsCompleted = SettingKey<int>(
    name: '${SettingKey.localPrefix}rowsCompleted',
    defaultValue: 0,
    encode: _encodeInt,
    decode: int.tryParse,
  );

  /// Режим плетения «по бусине» (иначе «по ряду»): запоминается между запусками.
  static const SettingKey<bool> weaveByBead = SettingKey<bool>(
    name: 'weaveByBead',
    defaultValue: false,
    encode: _encodeBool,
    decode: _decodeBool,
  );

  static String _identity(String value) => value;

  static String _encodeInt(int value) => value.toString();

  static String _encodeBool(bool value) => value ? 'true' : 'false';

  static bool? _decodeBool(String raw) => switch (raw) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  // Имя значения enum хранится в базе: переименовывать значения нельзя, иначе настройка сбросится на умолчание.
  static String _encodeEnum(AppThemeMode value) => value.name;

  static AppThemeMode? _decodeThemeMode(String raw) {
    for (final AppThemeMode mode in AppThemeMode.values) {
      if (mode.name == raw) {
        return mode;
      }
    }
    return null;
  }

  static String _encodeSpecialDates(List<SpecialDate> value) => jsonEncode(<Map<String, Object>>[
    for (final SpecialDate date in value) <String, Object>{'label': date.label, 'month': date.month, 'day': date.day},
  ]);

  // Проверяем только диапазоны: невозможные даты вроде 31 февраля сверяются при показе.
  static List<SpecialDate>? _decodeSpecialDates(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! List<Object?>) {
      return null;
    }
    final List<SpecialDate> dates = <SpecialDate>[];
    for (final Object? item in json) {
      if (item is! Map<String, Object?>) {
        return null;
      }
      final Object? label = item['label'];
      final Object? month = item['month'];
      final Object? day = item['day'];
      if (label is! String || month is! int || day is! int || month < 1 || month > 12 || day < 1 || day > 31) {
        return null;
      }
      dates.add(SpecialDate(label: label, month: month, day: day));
    }
    return List<SpecialDate>.unmodifiable(dates);
  }
}
