import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:beading/presentation/theme/theme_mode_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_settings_repository.dart';

void main() {
  test('до восстановления режим системный', () {
    expect(ThemeModeCubit(FakeSettingsRepository(themeMode: AppThemeMode.dark)).state, AppThemeMode.system);
  });

  blocTest<ThemeModeCubit, AppThemeMode>(
    'restore восстанавливает сохранённый режим',
    build: () => ThemeModeCubit(FakeSettingsRepository(themeMode: AppThemeMode.dark)),
    act: (cubit) => cubit.restore(),
    expect: () => <AppThemeMode>[AppThemeMode.dark],
  );

  blocTest<ThemeModeCubit, AppThemeMode>(
    'restore с тем же значением ничего не испускает',
    build: () => ThemeModeCubit(FakeSettingsRepository()),
    act: (cubit) => cubit.restore(),
    expect: () => <AppThemeMode>[],
  );

  blocTest<ThemeModeCubit, AppThemeMode>(
    'select переключает режим и сохраняет его',
    build: () => ThemeModeCubit(FakeSettingsRepository()),
    act: (cubit) async {
      await cubit.select(AppThemeMode.light);
      await cubit.select(AppThemeMode.dark);
    },
    expect: () => <AppThemeMode>[AppThemeMode.light, AppThemeMode.dark],
    verify: (cubit) => expect(cubit.state, AppThemeMode.dark),
  );

  test('выбранный режим переживает пересоздание cubit', () async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await ThemeModeCubit(repository).select(AppThemeMode.light);

    final ThemeModeCubit restored = ThemeModeCubit(repository);
    await restored.restore();

    expect(restored.state, AppThemeMode.light);
    expect(repository.saveCount, 1);
  });
}
