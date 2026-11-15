import 'package:beading/app/composition/book_module.dart';
import 'package:beading/app/composition/catalog_module.dart';
import 'package:beading/app/composition/core_module.dart';
import 'package:beading/app/composition/easter_eggs_module.dart';
import 'package:beading/app/composition/grid_module.dart';
import 'package:beading/app/composition/image_to_grid_module.dart';
import 'package:beading/app/composition/projects_module.dart';
import 'package:beading/app/composition/settings_module.dart';
import 'package:beading/app/composition/sharing_module.dart';
import 'package:beading/app/composition/stitching_module.dart';
import 'package:beading/app/composition/sync_module.dart';
import 'package:beading/app/composition/weaving_module.dart';
import 'package:beading/data/catalog/catalog_asset_source.dart';
import 'package:beading/domain/projects/project_content_cleaner.dart';
import 'package:beading/domain/projects/project_content_cloner.dart';

/// Корень графа зависимостей (ADR-0007): держит модули фич, создаётся в `bootstrap` и передаётся через конструкторы.
final class AppDependencies {
  AppDependencies({required this.core, this.sync, CatalogAssetSource? catalogAssets})
    : catalog = CatalogModule(core: core, assets: catalogAssets),
      easterEggs = EasterEggsModule(core: core),
      settings = SettingsModule(core: core) {
    projects = ProjectsModule(
      core: core,
      // Порядок как при удалении: схемы-картинки, сетки, рецепты мастера, сеансы работы.
      cleaners: () => <ProjectContentCleaner>[
        book.contentCleaner,
        grid.contentCleaner,
        imageToGrid.contentCleaner,
        weaving.contentCleaner,
      ],
      cloners: () => <ProjectContentCloner>[book.contentCloner, grid.contentCloner],
    );
    grid = GridModule(core: core, projects: projects, catalog: catalog);
    weaving = WeavingModule(core: core, projects: projects, grid: grid);
    stitching = StitchingModule(
      core: core,
      projects: projects,
      grid: grid,
      weaving: weaving,
      catalog: catalog,
    );
    book = BookModule(core: core, projects: projects);
    imageToGrid = ImageToGridModule(core: core, projects: projects, grid: grid, catalog: catalog);
    sharing = SharingModule(
      core: core,
      projects: projects,
      grid: grid,
      book: book,
      weaving: weaving,
      catalog: catalog,
      settings: settings,
    );
  }

  final CoreModule core;
  final CatalogModule catalog;
  late final ProjectsModule projects;
  late final GridModule grid;
  late final WeavingModule weaving;
  late final StitchingModule stitching;
  late final BookModule book;
  late final ImageToGridModule imageToGrid;
  late final SharingModule sharing;
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
    await sharing.dispose();
    await easterEggs.dispose();
    await core.dispose();
  }
}
