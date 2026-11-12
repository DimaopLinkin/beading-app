import 'package:beading/app/composition/core_module.dart';
import 'package:beading/app/composition/easter_eggs_module.dart';
import 'package:beading/app/composition/settings_module.dart';

/// Корень графа зависимостей (ADR-0007): держит модули фич, создаётся в `bootstrap` и передаётся через конструкторы.
///
/// Пока миграция идёт, ещё не переведённые фичи собирает `di.dart`, беря ядро отсюда.
final class AppDependencies {
  AppDependencies({required this.core})
    : easterEggs = EasterEggsModule(core: core),
      settings = SettingsModule(core: core);

  final CoreModule core;
  final EasterEggsModule easterEggs;
  final SettingsModule settings;

  bool _disposed = false;

  /// Закрывает объекты приложения в обратном порядке создания. Повторный вызов ничего не делает.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await easterEggs.dispose();
    await core.dispose();
  }
}
