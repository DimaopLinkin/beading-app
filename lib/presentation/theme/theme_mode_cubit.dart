import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:beading/domain/settings/settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Режим темы: системный, светлый или тёмный. Выбор сохраняется в [SettingsRepository].
class ThemeModeCubit extends Cubit<AppThemeMode> {
  ThemeModeCubit(this._settings) : super(AppThemeMode.system);

  final SettingsRepository _settings;

  /// Подставляет сохранённый режим; вызывается один раз при запуске.
  Future<void> restore() async {
    final AppThemeMode saved = await _settings.loadThemeMode();
    if (saved != state) emit(saved);
  }

  Future<void> select(AppThemeMode mode) async {
    emit(mode);
    await _settings.saveThemeMode(mode);
  }
}
