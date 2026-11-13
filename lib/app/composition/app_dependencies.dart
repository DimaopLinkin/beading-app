import 'package:beading/app/composition/catalog_module.dart';
import 'package:beading/app/composition/core_module.dart';
import 'package:beading/app/composition/easter_eggs_module.dart';
import 'package:beading/app/composition/settings_module.dart';
import 'package:beading/app/composition/sync_module.dart';
import 'package:beading/data/catalog/catalog_asset_source.dart';

/// Корень графа зависимостей (ADR-0007): держит модули фич, создаётся в `bootstrap` и передаётся через конструкторы.
///
/// Пока миграция идёт, ещё не переведённые фичи собирает `di.dart`, беря ядро отсюда.
final class AppDependencies {
  AppDependencies({required this.core, this.sync, CatalogAssetSource? catalogAssets})
    : catalog = CatalogModule(core: core, assets: catalogAssets),
      easterEggs = EasterEggsModule(core: core),
      settings = SettingsModule(core: core);

  final CoreModule core;
  final CatalogModule catalog;
  final EasterEggsModule easterEggs;
  final SettingsModule settings;

  /// `null`, если сборка не знает адрес Supabase: синхронизации нет, приложение работает локально.
  final SyncModule? sync;

  bool _disposed = false;

  /// Закрывает объекты приложения в обратном порядке создания. Повторный вызов ничего не делает.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await sync?.dispose();
    await easterEggs.dispose();
    await core.dispose();
  }
}
