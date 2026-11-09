import 'package:beading/core/clock.dart';
import 'package:beading/core/id_generator.dart';
import 'package:get_it/get_it.dart';

/// Глобальный контейнер зависимостей. Регистрируем только здесь.
final GetIt getIt = GetIt.instance;

/// Регистрирует сервисы в [locator]; повторный вызов сбрасывает прежние регистрации.
Future<void> configureDependencies([GetIt? locator]) async {
  final GetIt container = locator ?? getIt;
  await container.reset();
  container
    ..registerLazySingleton<Clock>(SystemClock.new)
    ..registerLazySingleton<IdGenerator>(() => UuidV7IdGenerator(clock: container<Clock>()));
}
