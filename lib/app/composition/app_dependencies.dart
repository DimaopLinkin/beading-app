import 'package:beading/app/composition/catalog_module.dart';
import 'package:beading/app/composition/core_module.dart';
import 'package:beading/app/composition/easter_eggs_module.dart';
import 'package:beading/app/composition/grid_module.dart';
import 'package:beading/app/composition/projects_module.dart';
import 'package:beading/app/composition/settings_module.dart';
import 'package:beading/app/composition/stitching_module.dart';
import 'package:beading/app/composition/weaving_module.dart';
import 'package:beading/data/catalog/catalog_asset_source.dart';

/// Корень графа зависимостей (ADR-0007): держит модули фич, создаётся в `bootstrap` и передаётся через конструкторы.
///
/// Пока миграция идёт, ещё не переведённые фичи собирает `di.dart`, беря ядро отсюда.
final class AppDependencies {
  AppDependencies({required this.core, CatalogAssetSource? catalogAssets})
    : catalog = CatalogModule(core: core, assets: catalogAssets),
      projects = ProjectsModule(core: core),
      easterEggs = EasterEggsModule(core: core),
      settings = SettingsModule(core: core) {
    grid = GridModule(core: core, projects: projects, catalog: catalog);
    weaving = WeavingModule(core: core, projects: projects, grid: grid);
    stitching = StitchingModule(
      core: core,
      projects: projects,
      grid: grid,
      weaving: weaving,
      catalog: catalog,
    );
  }

  final CoreModule core;
  final CatalogModule catalog;
  final ProjectsModule projects;
  late final GridModule grid;
  late final WeavingModule weaving;
  late final StitchingModule stitching;
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
