/// Настройка «Не гасить экран». По умолчанию включена.
///
/// Реализация — поверх `SettingsRepository` (ключ `SettingKeys.keepScreenAwake`).
abstract interface class KeepScreenAwakeSetting {
  Future<bool> read();

  /// Новые значения после каждого изменения настройки.
  Stream<bool> watch();
}
