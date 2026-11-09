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

  /// Ключи, которые пользовательница уже меняла: поздняя загрузка их не затирает.
  final Set<String> _touched = <String>{};

  Future<void> load() async {
    final bool keepAwake = await _read(SettingKeys.keepScreenAwake);
    final bool symbols = await _read(SettingKeys.symbolMode);
    final String brand = await _read(SettingKeys.defaultBeadBrand);
    final String name = await _read(SettingKeys.userName);
    final List<SpecialDate> dates = await _read(SettingKeys.specialDates);
    if (isClosed) return;
    bool free(SettingKey<Object?> key) => !_touched.contains(key.name);
    emit(
      state.copyWith(
        keepScreenAwake: free(SettingKeys.keepScreenAwake) ? keepAwake : null,
        symbolMode: free(SettingKeys.symbolMode) ? symbols : null,
        defaultBeadBrand: free(SettingKeys.defaultBeadBrand) ? brand : null,
        userName: free(SettingKeys.userName) ? name : null,
        specialDates: free(SettingKeys.specialDates) ? dates : null,
        loaded: true,
      ),
    );
  }

  Future<void> setKeepScreenAwake({required bool value}) => _apply(
    SettingKeys.keepScreenAwake,
    value,
    (s) => s.keepScreenAwake,
    (s, v) => s.copyWith(keepScreenAwake: v),
  );

  Future<void> setSymbolMode({required bool value}) => _apply(
    SettingKeys.symbolMode,
    value,
    (s) => s.symbolMode,
    (s, v) => s.copyWith(symbolMode: v),
  );

  Future<void> setDefaultBeadBrand(String brand) => _apply(
    SettingKeys.defaultBeadBrand,
    brand,
    (s) => s.defaultBeadBrand,
    (s, v) => s.copyWith(defaultBeadBrand: v),
  );

  /// Пустое имя (после обрезки пробелов) возвращает имя по умолчанию; длиннее [userNameMaxLength] обрезается.
  Future<void> setUserName(String name) {
    final String trimmed = name.trim();
    final String limited = trimmed.length > userNameMaxLength ? trimmed.substring(0, userNameMaxLength) : trimmed;
    return _apply(
      SettingKeys.userName,
      limited.isEmpty ? SettingKeys.userName.defaultValue : limited,
      (s) => s.userName,
      (s, v) => s.copyWith(userName: v),
    );
  }

  Future<void> addSpecialDate(SpecialDate date) => _setDates(<SpecialDate>[...state.specialDates, date]);

  Future<void> removeSpecialDate(SpecialDate date) => _setDates(<SpecialDate>[...state.specialDates]..remove(date));

  Future<void> _setDates(List<SpecialDate> dates) => _apply(
    SettingKeys.specialDates,
    List<SpecialDate>.unmodifiable(dates),
    (s) => s.specialDates,
    (s, v) => s.copyWith(specialDates: v),
  );

  Future<T> _read<T>(SettingKey<T> key) async => (await _settings.read(key)).valueOrNull ?? key.defaultValue;

  /// Применяет значение сразу и пишет его. Если запись не удалась, откатывает поле, но только если его
  /// за это время не изменили ещё раз: иначе откат затёр бы более свежее значение.
  Future<void> _apply<T>(
    SettingKey<T> key,
    T value,
    T Function(SettingsState state) read,
    SettingsState Function(SettingsState state, T value) update,
  ) async {
    final T previous = read(state);
    _touched.add(key.name);
    emit(update(state, value).copyWith(saveFailed: false));
    final Result<void> result = await _settings.write(key, value);
    if (result.isFailure && !isClosed) {
      final SettingsState failed = state.copyWith(saveFailed: true);
      emit(read(state) == value ? update(failed, previous) : failed);
    }
  }
}
