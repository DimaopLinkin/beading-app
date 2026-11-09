import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/special_date.dart';
import 'package:equatable/equatable.dart';

/// Значения настроек, которые показывает экран. Тема живёт в `ThemeModeCubit`.
final class SettingsState extends Equatable {
  const SettingsState({
    this.keepScreenAwake = true,
    this.symbolMode = false,
    this.defaultBeadBrand = 'Miyuki',
    this.userName = 'Настя',
    this.specialDates = const <SpecialDate>[],
    this.loaded = false,
    this.saveFailed = false,
  });

  /// Значения по умолчанию берём из [SettingKeys]: единый источник.
  factory SettingsState.defaults() => SettingsState(
    keepScreenAwake: SettingKeys.keepScreenAwake.defaultValue,
    symbolMode: SettingKeys.symbolMode.defaultValue,
    defaultBeadBrand: SettingKeys.defaultBeadBrand.defaultValue,
    userName: SettingKeys.userName.defaultValue,
    specialDates: SettingKeys.specialDates.defaultValue,
  );

  final bool keepScreenAwake;
  final bool symbolMode;
  final String defaultBeadBrand;
  final String userName;
  final List<SpecialDate> specialDates;
  final bool loaded;

  /// Последняя запись не удалась: экран показывает предупреждение, значение откатано.
  final bool saveFailed;

  SettingsState copyWith({
    bool? keepScreenAwake,
    bool? symbolMode,
    String? defaultBeadBrand,
    String? userName,
    List<SpecialDate>? specialDates,
    bool? loaded,
    bool? saveFailed,
  }) => SettingsState(
    keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
    symbolMode: symbolMode ?? this.symbolMode,
    defaultBeadBrand: defaultBeadBrand ?? this.defaultBeadBrand,
    userName: userName ?? this.userName,
    specialDates: specialDates ?? this.specialDates,
    loaded: loaded ?? this.loaded,
    saveFailed: saveFailed ?? this.saveFailed,
  );

  @override
  List<Object?> get props => <Object?>[
    keepScreenAwake,
    symbolMode,
    defaultBeadBrand,
    userName,
    specialDates,
    loaded,
    saveFailed,
  ];
}
