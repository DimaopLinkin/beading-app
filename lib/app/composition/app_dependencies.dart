import 'package:beading/app/composition/core_module.dart';

/// Корень графа зависимостей (ADR-0007): держит модули фич, создаётся в `bootstrap` и передаётся через конструкторы.
///
/// Пока миграция идёт, ещё не переведённые фичи собирает `di.dart`, беря ядро отсюда.
final class AppDependencies {
  AppDependencies({required this.core});

  /// Открывает файловую базу и собирает граф; [database] подменяет её в тестах.
  static Future<AppDependencies> create({CoreModule? core}) async =>
      AppDependencies(core: core ?? await CoreModule.open());

  final CoreModule core;

  bool _disposed = false;

  /// Закрывает объекты приложения в обратном порядке создания. Повторный вызов ничего не делает.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await core.dispose();
  }
}
