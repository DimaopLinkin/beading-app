import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:beading/domain/settings/settings_repository.dart';

/// Фейк настроек для тестов: хранит значения в памяти и считает записи.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({this.themeMode = AppThemeMode.system});

  AppThemeMode themeMode;
  int saveCount = 0;

  @override
  Future<AppThemeMode> loadThemeMode() async => themeMode;

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async {
    saveCount++;
    themeMode = mode;
  }
}
