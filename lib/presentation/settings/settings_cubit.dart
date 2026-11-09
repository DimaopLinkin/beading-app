import 'package:beading/core/result.dart';
import 'package:beading/domain/settings/setting_key.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/settings_repository.dart';
import 'package:beading/domain/settings/special_date.dart';
import 'package:beading/presentation/settings/settings_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Настройки экрана «Настройки»: переключатели, бренд, имя и даты пасхалок. Изменение применяется сразу:
/// состояние обновляется до записи, при ошибке записи значение откатывается и ставится `saveFailed`.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._settings) : super(SettingsState.defaults());

  final SettingsRepository _settings;

  Future<void> load() async {
    final bool keepAwake = await _read(SettingKeys.keepScreenAwake);
    final bool symbols = await _read(SettingKeys.symbolMode);
    final String brand = await _read(SettingKeys.defaultBeadBrand);
    final String name = await _read(SettingKeys.userName);
    final List<SpecialDate> dates = await _read(SettingKeys.specialDates);
    if (isClosed) return;
    emit(
      state.copyWith(
        keepScreenAwake: keepAwake,
        symbolMode: symbols,
        defaultBeadBrand: brand,
        userName: name,
        specialDates: dates,
        loaded: true,
      ),
    );
  }

  Future<void> setKeepScreenAwake({required bool value}) => _apply(
    SettingKeys.keepScreenAwake,
    value,
    state.keepScreenAwake,
    (s, v) => s.copyWith(keepScreenAwake: v),
  );

  Future<void> setSymbolMode({required bool value}) => _apply(
    SettingKeys.symbolMode,
    value,
    state.symbolMode,
    (s, v) => s.copyWith(symbolMode: v),
  );

  Future<void> setDefaultBeadBrand(String brand) => _apply(
    SettingKeys.defaultBeadBrand,
    brand,
    state.defaultBeadBrand,
    (s, v) => s.copyWith(defaultBeadBrand: v),
  );

  /// Пустое имя (после обрезки пробелов) возвращает имя по умолчанию.
  Future<void> setUserName(String name) {
    final String trimmed = name.trim();
    return _apply(
      SettingKeys.userName,
      trimmed.isEmpty ? SettingKeys.userName.defaultValue : trimmed,
      state.userName,
      (s, v) => s.copyWith(userName: v),
    );
  }

  Future<void> addSpecialDate(SpecialDate date) => _setDates(<SpecialDate>[...state.specialDates, date]);

  Future<void> removeSpecialDate(SpecialDate date) => _setDates(<SpecialDate>[...state.specialDates]..remove(date));

  Future<void> _setDates(List<SpecialDate> dates) => _apply(
    SettingKeys.specialDates,
    List<SpecialDate>.unmodifiable(dates),
    state.specialDates,
    (s, v) => s.copyWith(specialDates: v),
  );

  Future<T> _read<T>(SettingKey<T> key) async => (await _settings.read(key)).valueOrNull ?? key.defaultValue;

  Future<void> _apply<T>(
    SettingKey<T> key,
    T value,
    T previous,
    SettingsState Function(SettingsState state, T value) update,
  ) async {
    emit(update(state, value).copyWith(saveFailed: false));
    final Result<void> result = await _settings.write(key, value);
    if (result.isFailure && !isClosed) {
      emit(update(state, previous).copyWith(saveFailed: true));
    }
  }
}
