import 'package:beading/domain/settings/app_theme_mode.dart';

/// Хранилище пользовательских настроек. Реализация на БД — в T03; до неё в DI лежит версия в памяти.
abstract interface class SettingsRepository {
  Future<AppThemeMode> loadThemeMode();

  Future<void> saveThemeMode(AppThemeMode mode);
}
