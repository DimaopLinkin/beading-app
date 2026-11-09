import 'dart:async';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/settings/repository_keep_screen_awake_setting.dart';
import 'package:beading/domain/settings/setting_key.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_settings_repository.dart';

class _FailingRepository extends FakeSettingsRepository {
  @override
  Future<Result<T>> read<T>(SettingKey<T> key) async => Err<T>(const StorageFailure('boom'));

  @override
  Stream<T> watch<T>(SettingKey<T> key) => Stream<T>.error(Exception('boom'));
}

void main() {
  test('по умолчанию включено', () async {
    expect(await RepositoryKeepScreenAwakeSetting(FakeSettingsRepository()).read(), isTrue);
  });

  test('читает сохранённое значение и отдаёт его в watch', () async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await repository.write(SettingKeys.keepScreenAwake, false);
    final RepositoryKeepScreenAwakeSetting setting = RepositoryKeepScreenAwakeSetting(repository);

    expect(await setting.read(), isFalse);
    expect(await setting.watch().first, isFalse);
  });

  test('сбой хранилища: читаем значение по умолчанию, ошибки потока гасим', () async {
    final RepositoryKeepScreenAwakeSetting setting = RepositoryKeepScreenAwakeSetting(_FailingRepository());

    expect(await setting.read(), isTrue);
    expect(await setting.watch().toList(), isEmpty);
  });
}
