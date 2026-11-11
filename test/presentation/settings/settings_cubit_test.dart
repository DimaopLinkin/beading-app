import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/special_date.dart';
import 'package:beading/presentation/settings/settings_cubit.dart';
import 'package:beading/presentation/settings/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_settings_repository.dart';

void main() {
  late FakeSettingsRepository repo;
  late SettingsCubit cubit;

  setUp(() {
    repo = FakeSettingsRepository();
    cubit = SettingsCubit(repo);
  });

  tearDown(() => cubit.close());

  test('начальное состояние — значения по умолчанию, не загружено', () {
    expect(cubit.state, SettingsState.defaults());
    expect(cubit.state.loaded, isFalse);
  });

  test('load подставляет сохранённые значения', () async {
    repo.values[SettingKeys.symbolMode.name] = true;
    repo.values[SettingKeys.keepScreenAwake.name] = false;
    repo.values[SettingKeys.defaultBeadBrand.name] = 'Toho';
    repo.values[SettingKeys.userName.name] = 'Аня';

    await cubit.load();

    expect(cubit.state.loaded, isTrue);
    expect(cubit.state.symbolMode, isTrue);
    expect(cubit.state.keepScreenAwake, isFalse);
    expect(cubit.state.defaultBeadBrand, 'Toho');
    expect(cubit.state.userName, 'Аня');
  });

  test('переключатели применяются сразу и пишутся в хранилище', () async {
    final Future<void> pending = cubit.setKeepScreenAwake(value: false);
    expect(cubit.state.keepScreenAwake, isFalse); // до завершения записи
    await pending;
    await cubit.setSymbolMode(value: true);

    expect(repo.values[SettingKeys.keepScreenAwake.name], false);
    expect(repo.values[SettingKeys.symbolMode.name], true);
    expect(cubit.state.saveFailed, isFalse);
  });

  test('бренд по умолчанию сохраняется', () async {
    await cubit.setDefaultBeadBrand('Preciosa');

    expect(cubit.state.defaultBeadBrand, 'Preciosa');
    expect(repo.values[SettingKeys.defaultBeadBrand.name], 'Preciosa');
  });

  test('мулине по умолчанию сохраняется отдельно от бисера', () async {
    await cubit.setDefaultFlossBrand('DMC');

    expect(cubit.state.defaultFlossBrand, 'DMC');
    expect(cubit.state.defaultBeadBrand, SettingKeys.defaultBeadBrand.defaultValue);
    expect(repo.values[SettingKeys.defaultFlossBrand.name], 'DMC');
  });

  test('имя обрезается, пустое возвращает значение по умолчанию', () async {
    await cubit.setUserName('  Оля ');
    expect(cubit.state.userName, 'Оля');

    await cubit.setUserName('   ');
    expect(cubit.state.userName, SettingKeys.userName.defaultValue);
  });

  test('даты добавляются и удаляются', () async {
    const SpecialDate birthday = SpecialDate(label: 'День рождения', month: 5, day: 17);
    const SpecialDate march8 = SpecialDate(label: '8 марта', month: 3, day: 8);

    await cubit.addSpecialDate(birthday);
    await cubit.addSpecialDate(march8);
    expect(cubit.state.specialDates, <SpecialDate>[birthday, march8]);
    expect(repo.values[SettingKeys.specialDates.name], <SpecialDate>[birthday, march8]);

    await cubit.removeSpecialDate(birthday);
    expect(cubit.state.specialDates, <SpecialDate>[march8]);
  });

  test('при ошибке записи значение откатывается и ставится saveFailed', () async {
    repo.failWrites = true;

    await cubit.setSymbolMode(value: true);

    expect(cubit.state.symbolMode, isFalse);
    expect(cubit.state.saveFailed, isTrue);

    repo.failWrites = false;
    await cubit.setSymbolMode(value: true);
    expect(cubit.state.saveFailed, isFalse);
  });

  test('откат не затирает более свежее значение', () async {
    repo.failWrites = true;
    final Future<void> first = cubit.setSymbolMode(value: true);
    repo.failWrites = false;
    await cubit.setSymbolMode(value: false);
    await first;
    // Первая запись упала, но поле уже изменено второй: оно остаётся как есть.
    expect(cubit.state.symbolMode, isFalse);
  });

  test('load не затирает значение, которое успели изменить', () async {
    repo.values[SettingKeys.symbolMode.name] = false;
    final Future<void> loading = cubit.load();
    await cubit.setSymbolMode(value: true);
    await loading;

    expect(cubit.state.symbolMode, isTrue);
    expect(cubit.state.loaded, isTrue);
  });

  test('слишком длинное имя обрезается до userNameMaxLength', () async {
    await cubit.setUserName('а' * 100);

    expect(cubit.state.userName, hasLength(userNameMaxLength));
  });

  test('обрезка имени не рвёт эмодзи', () async {
    await cubit.setUserName('😀' * 100);

    expect(cubit.state.userName.runes, hasLength(userNameMaxLength));
    expect(cubit.state.userName.runes.every((r) => r == 0x1F600), isTrue);
  });
}
