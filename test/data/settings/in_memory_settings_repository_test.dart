import 'package:beading/data/settings/in_memory_settings_repository.dart';
import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('по умолчанию режим темы — системный', () async {
    expect(await InMemorySettingsRepository().loadThemeMode(), AppThemeMode.system);
  });

  test('сохранённый режим читается обратно', () async {
    final InMemorySettingsRepository repository = InMemorySettingsRepository();

    await repository.saveThemeMode(AppThemeMode.dark);

    expect(await repository.loadThemeMode(), AppThemeMode.dark);
  });
}
