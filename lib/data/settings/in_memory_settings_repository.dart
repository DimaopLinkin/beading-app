import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:beading/domain/settings/settings_repository.dart';

/// Настройки в памяти: временная реализация до появления БД (T03).
class InMemorySettingsRepository implements SettingsRepository {
  AppThemeMode _themeMode = AppThemeMode.system;

  @override
  Future<AppThemeMode> loadThemeMode() async => _themeMode;

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async => _themeMode = mode;
}
