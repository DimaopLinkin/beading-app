import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:beading/domain/settings/setting_key.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/special_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('значения по умолчанию', () {
    test('соответствуют требованиям', () {
      expect(SettingKeys.themeMode.defaultValue, AppThemeMode.system);
      expect(SettingKeys.keepScreenAwake.defaultValue, isTrue);
      expect(SettingKeys.symbolMode.defaultValue, isFalse);
      expect(SettingKeys.defaultBeadBrand.defaultValue, 'Miyuki');
      expect(SettingKeys.defaultFlossBrand.defaultValue, 'DMC');
      expect(SettingKeys.userName.defaultValue, 'Настя');
      expect(SettingKeys.specialDates.defaultValue, isEmpty);
    });

    test('имена ключей уникальны и не начинаются с local.', () {
      final List<String> names = <String>[
        SettingKeys.themeMode.name,
        SettingKeys.keepScreenAwake.name,
        SettingKeys.symbolMode.name,
        SettingKeys.defaultBeadBrand.name,
        SettingKeys.defaultFlossBrand.name,
        SettingKeys.userName.name,
        SettingKeys.specialDates.name,
      ];

      expect(names.toSet(), hasLength(names.length));
      expect(names.where(SettingKey.isLocalName), isEmpty);
      expect(SettingKeys.userName.isLocal, isFalse);
      expect(SettingKey.isLocalName('local.deviceId'), isTrue);
    });
  });

  test('toString показывает имя ключа', () {
    expect(SettingKeys.userName.toString(), 'SettingKey(userName)');
  });

  group('encode/decode', () {
    void roundTrip<T>(SettingKey<T> key, T value) {
      expect(key.decode(key.encode(value)), value, reason: key.name);
    }

    test('туда и обратно', () {
      for (final AppThemeMode mode in AppThemeMode.values) {
        roundTrip(SettingKeys.themeMode, mode);
      }
      roundTrip(SettingKeys.keepScreenAwake, true);
      roundTrip(SettingKeys.keepScreenAwake, false);
      roundTrip(SettingKeys.symbolMode, true);
      roundTrip(SettingKeys.defaultBeadBrand, 'Toho');
      roundTrip(SettingKeys.defaultFlossBrand, 'Гамма');
      roundTrip(SettingKeys.userName, 'Анастасия');
      roundTrip(SettingKeys.userName, '');
      roundTrip(SettingKeys.specialDates, const <SpecialDate>[
        SpecialDate(label: 'День рождения', month: 3, day: 14),
        SpecialDate(label: '8 марта', month: 3, day: 8),
      ]);
      roundTrip(SettingKeys.specialDates, const <SpecialDate>[]);
    });

    test('повреждённые значения не разбираются', () {
      expect(SettingKeys.themeMode.decode('neon'), isNull);
      expect(SettingKeys.keepScreenAwake.decode('yes'), isNull);
      expect(SettingKeys.symbolMode.decode(''), isNull);
      expect(SettingKeys.specialDates.decode('не json'), isNull);
      expect(SettingKeys.specialDates.decode('{"a":1}'), isNull);
      expect(SettingKeys.specialDates.decode('[1]'), isNull);
      expect(SettingKeys.specialDates.decode('[{"label":"x","month":13,"day":1}]'), isNull);
      expect(SettingKeys.specialDates.decode('[{"label":"x","month":1,"day":0}]'), isNull);
      expect(SettingKeys.specialDates.decode('[{"label":1,"month":1,"day":1}]'), isNull);
    });
  });
}
