import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:beading/domain/settings/settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Режим темы: системный, светлый или тёмный. Выбор сохраняется в [SettingsRepository].
class ThemeModeCubit extends Cubit<AppThemeMode> {
  ThemeModeCubit(this._settings) : super(AppThemeMode.system);

  final SettingsRepository _settings;
  bool _selected = false;

  /// Подставляет сохранённый режим; вызывается один раз при запуске.
  Future<void> restore() async {
    final AppThemeMode saved = await _settings.loadThemeMode();
    // Выбор пользователя важнее восстановленного значения, если он успел раньше.
    if (!_selected && saved != state) emit(saved);
  }

  Future<void> select(AppThemeMode mode) async {
    _selected = true;
    emit(mode);
    await _settings.saveThemeMode(mode);
  }
}
