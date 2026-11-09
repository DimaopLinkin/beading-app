import 'package:beading/app/di.dart';
import 'package:beading/core/clock.dart';
import 'package:beading/core/id_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  test('configureDependencies регистрирует базовые сервисы', () async {
    final GetIt locator = GetIt.asNewInstance();

    await configureDependencies(locator);

    expect(locator<Clock>(), isA<SystemClock>());
    expect(locator<IdGenerator>(), isA<UuidV7IdGenerator>());
  });

  test('повторная настройка не падает и пересоздаёт регистрации', () async {
    final GetIt locator = GetIt.asNewInstance();

    await configureDependencies(locator);
    await configureDependencies(locator);

    expect(locator.isRegistered<Clock>(), isTrue);
  });
}
