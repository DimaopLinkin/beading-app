import 'package:beading/app/composition/app_dependencies.dart';
import 'package:beading/app/composition/app_routes.dart';
import 'package:beading/app/composition/core_module.dart';
import 'package:beading/core/clock.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/data/catalog/catalog_asset_source.dart';
import 'package:beading/data/catalog/drift_catalog_repository.dart';
import 'package:beading/data/easter_eggs/asset_compliment_source.dart';
import 'package:beading/data/easter_eggs/drift_easter_egg_log.dart';
import 'package:beading/data/floss_stock/drift_floss_stock_repository.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/data/settings/drift_settings_repository.dart';
import 'package:beading/data/settings/package_info_app_info_provider.dart';
import 'package:beading/domain/catalog/use_cases/find_similar_colors.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/load_project_preview.dart';
import 'package:beading/domain/projects/use_cases/delete_project.dart';
import 'package:beading/domain/projects/use_cases/duplicate_project.dart';
import 'package:beading/domain/settings/app_events_secret_tap_handler.dart';
import 'package:beading/presentation/book_work/book_work_cubit.dart';
import 'package:beading/presentation/book_work/book_work_screen.dart';
import 'package:beading/presentation/catalog/catalog_cubit.dart';
import 'package:beading/presentation/easter_eggs/compliment_banner_cubit.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_cubit.dart';
import 'package:beading/presentation/import_book/import_book_cubit.dart';
import 'package:beading/presentation/library/library_cubit.dart';
import 'package:beading/presentation/settings/settings_cubit.dart';
import 'package:beading/presentation/sharing/data_transfer_cubit.dart';
import 'package:beading/presentation/theme/theme_mode_cubit.dart';
import 'package:beading/presentation/weaving/weave_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_clock.dart';
import '../../support/in_memory_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CoreModule', () {
    test('собирает ядро из базы без глобального состояния', () {
      final CoreModule core = CoreModule(database: createInMemoryDatabase());
      addTearDown(core.dispose);

      expect(core.clock, isA<SystemClock>());
      expect(core.ids, isA<UuidV7IdGenerator>());
      expect(core.deviceIds, isA<DriftDeviceIdProvider>());
      expect(core.settings, isA<DriftSettingsRepository>());
      expect(core.events, isA<BroadcastAppEvents>());
    });

    test('объекты ядра создаются один раз', () {
      final CoreModule core = CoreModule(database: createInMemoryDatabase());
      addTearDown(core.dispose);

      expect(core.settings, same(core.settings));
      expect(core.events, same(core.events));
    });

    test('принимает подмену часов', () {
      final Clock fake = FakeClock(DateTime.utc(2026, 11, 12));
      final CoreModule core = CoreModule(database: createInMemoryDatabase(), clock: fake);
      addTearDown(core.dispose);

      expect(core.clock, same(fake));
    });
  });

  group('AppDependencies', () {
    test('держит ядро', () {
      final CoreModule core = CoreModule(database: createInMemoryDatabase());
      final AppDependencies dependencies = AppDependencies(core: core);
      addTearDown(dependencies.dispose);

      expect(dependencies.core, same(core));
    });

    test('dispose можно вызвать повторно', () async {
      final AppDependencies dependencies = AppDependencies(
        core: CoreModule(database: createInMemoryDatabase()),
      );

      await dependencies.dispose();
      await dependencies.dispose();
    });
  });

  group('EasterEggsModule', () {
    test('собирает пасхалки и создаёт сервис один раз', () {
      final AppDependencies dependencies = AppDependencies(core: CoreModule(database: createInMemoryDatabase()));
      addTearDown(dependencies.dispose);

      expect(dependencies.easterEggs.log, isA<DriftEasterEggLog>());
      expect(dependencies.easterEggs.complimentSource, isA<AssetComplimentSource>());
      expect(dependencies.easterEggs.service, same(dependencies.easterEggs.service));
      expect(dependencies.easterEggs.longSession, same(dependencies.easterEggs.longSession));
    });

    test('баннер — новый объект на каждый вызов', () {
      final AppDependencies dependencies = AppDependencies(core: CoreModule(database: createInMemoryDatabase()));
      addTearDown(dependencies.dispose);

      final ComplimentBannerCubit first = dependencies.easterEggs.complimentBannerCubit();
      final ComplimentBannerCubit second = dependencies.easterEggs.complimentBannerCubit();
      addTearDown(first.close);
      addTearDown(second.close);

      expect(first, isNot(same(second)));
    });

    test('dispose закрывает созданные сервисы', () async {
      final AppDependencies dependencies = AppDependencies(core: CoreModule(database: createInMemoryDatabase()));
      dependencies.easterEggs
        ..service
        ..longSession;

      await dependencies.dispose();
    });
  });

  group('SettingsModule', () {
    test('отдаёт «О приложении» и обработчик секретных нажатий', () {
      final AppDependencies dependencies = AppDependencies(core: CoreModule(database: createInMemoryDatabase()));
      addTearDown(dependencies.dispose);

      expect(dependencies.settings.appInfo, isA<PackageInfoAppInfoProvider>());
      expect(dependencies.settings.secretTapHandler, isA<AppEventsSecretTapHandler>());
    });

    test('кубиты темы и настроек создаются заново на каждый вызов', () {
      final AppDependencies dependencies = AppDependencies(core: CoreModule(database: createInMemoryDatabase()));
      addTearDown(dependencies.dispose);

      final ThemeModeCubit theme = dependencies.settings.themeModeCubit();
      final SettingsCubit settings = dependencies.settings.settingsCubit();
      addTearDown(theme.close);
      addTearDown(settings.close);

      expect(theme, isNot(same(dependencies.settings.themeModeCubit())));
      expect(settings, isNot(same(dependencies.settings.settingsCubit())));
    });
  });

  group('CatalogModule', () {
    test('отдаёт репозиторий каталога и запас ниток один раз', () {
      final AppDependencies dependencies = AppDependencies(core: CoreModule(database: createInMemoryDatabase()));
      addTearDown(dependencies.dispose);

      expect(dependencies.catalog.repository, isA<DriftCatalogRepository>());
      expect(dependencies.catalog.repository, same(dependencies.catalog.repository));
      expect(dependencies.catalog.flossStock, isA<DriftFlossStockRepository>());
      expect(dependencies.catalog.findSimilarColors(), isA<FindSimilarColors>());
    });

    test('каталоги бисера и ниток — разные кубиты, новые на каждый вызов', () {
      final AppDependencies dependencies = AppDependencies(core: CoreModule(database: createInMemoryDatabase()));
      addTearDown(dependencies.dispose);

      final CatalogCubit beads = dependencies.catalog.beadCatalogCubit();
      final CatalogCubit floss = dependencies.catalog.flossCatalogCubit();
      addTearDown(beads.close);
      addTearDown(floss.close);

      expect(beads, isNot(same(floss)));
      expect(beads, isNot(same(dependencies.catalog.beadCatalogCubit())));
    });

    test('подменяет файлы каталога', () {
      final AppDependencies dependencies = AppDependencies(
        core: CoreModule(database: createInMemoryDatabase()),
        catalogAssets: _EmptyAssets(),
      );
      addTearDown(dependencies.dispose);

      expect(dependencies.catalog.assetSource, isA<_EmptyAssets>());
    });

    test('маршруты: бисер и мулине', () {
      final AppDependencies dependencies = AppDependencies(core: CoreModule(database: createInMemoryDatabase()));
      addTearDown(dependencies.dispose);

      expect(
        dependencies.catalog.routes().whereType<GoRoute>().map((r) => r.path),
        <String>[AppRoutes.flossCatalog, AppRoutes.catalog],
      );
    });
  });

  group('модули проектов, сеток, плетения и вышивки', () {
    late AppDependencies dependencies;

    setUp(() {
      dependencies = AppDependencies(core: CoreModule(database: createInMemoryDatabase()));
    });

    tearDown(() => dependencies.dispose());

    test('хранилища создаются один раз и общие для фич', () {
      expect(dependencies.projects.repository, same(dependencies.projects.repository));
      expect(dependencies.grid.patterns, same(dependencies.grid.patterns));
      expect(dependencies.grid.progress, same(dependencies.grid.progress));
      expect(dependencies.grid.cellProgress, same(dependencies.grid.cellProgress));
      expect(dependencies.weaving.sessions, same(dependencies.weaving.sessions));
      expect(dependencies.core.textSharer, same(dependencies.core.textSharer));
    });

    test('сценарии и счётчики создаются заново на каждый вызов', () {
      expect(dependencies.projects.createProject(), isNot(same(dependencies.projects.createProject())));
      expect(dependencies.grid.createGridPattern(), isNot(same(dependencies.grid.createGridPattern())));
      expect(dependencies.weaving.workSessionTracker(), isNot(same(dependencies.weaving.workSessionTracker())));
      expect(dependencies.weaving.rowsCounter(), isNot(same(dependencies.weaving.rowsCounter())));
    });

    test('кубиты экранов собираются для проекта и закрываются владельцем', () async {
      final List<Cubit<Object?>> cubits = <Cubit<Object?>>[
        dependencies.grid.editorCubit('p'),
        dependencies.grid.newGridCubit('Схема'),
        dependencies.grid.newStitchCubit('Вышивка'),
        dependencies.grid.patternTemplateCubit(),
        dependencies.weaving.weaveCubit('p'),
        dependencies.weaving.materialsCubit('p'),
        dependencies.stitching.stitchCubit('p'),
        dependencies.stitching.flossCubit('p'),
      ];

      expect(cubits, hasLength(8));
      await Future.wait(cubits.map((c) => c.close()));
    });

    test('маршруты фич не пересекаются по путям', () {
      final List<String> paths = <RouteBase>[
        ...dependencies.grid.routes(),
        ...dependencies.weaving.routes(),
        ...dependencies.stitching.routes(),
        ...dependencies.catalog.routes(),
        ...dependencies.settings.routes(showDeveloperTools: true, dataTransfer: () => throw UnimplementedError()),
      ].whereType<GoRoute>().map((r) => r.path).toList();

      expect(paths.toSet(), hasLength(paths.length));
      expect(paths, containsAll(<String>[AppRoutes.newGrid, AppRoutes.patternTemplate, WeaveScreen.routePath]));
    });
  });

  group('BookModule и ImageToGridModule', () {
    late AppDependencies dependencies;

    setUp(() {
      dependencies = AppDependencies(core: CoreModule(database: createInMemoryDatabase()));
    });

    tearDown(() => dependencies.dispose());

    test('хранилища книг создаются один раз', () {
      expect(dependencies.book.imagePatterns, same(dependencies.book.imagePatterns));
      expect(dependencies.book.bookWork, same(dependencies.book.bookWork));
      expect(dependencies.imageToGrid.recipes, same(dependencies.imageToGrid.recipes));
    });

    test('кубиты книги и мастера — новые на каждый вызов, со своими раннерами', () async {
      final ImportBookCubit importA = dependencies.book.importBookCubit();
      final ImportBookCubit importB = dependencies.book.importBookCubit();
      final ImageWizardCubit wizardA = dependencies.imageToGrid.imageWizardCubit();
      final ImageWizardCubit wizardB = dependencies.imageToGrid.imageWizardCubit();
      final BookWorkCubit work = dependencies.book.bookWorkCubit('p');

      expect(importA, isNot(same(importB)));
      expect(wizardA, isNot(same(wizardB)));
      await Future.wait(<Future<void>>[
        importA.close(),
        importB.close(),
        wizardA.close(),
        wizardB.close(),
        work.close(),
      ]);
    });

    test('маршруты: импорт книги, работа по книге и мастер', () {
      final List<String> paths = <RouteBase>[
        ...dependencies.book.routes(),
        ...dependencies.imageToGrid.routes(),
      ].whereType<GoRoute>().map((r) => r.path).toList();

      expect(paths, <String>[AppRoutes.importBook, BookWorkScreen.routePath, AppRoutes.imageToGrid]);
    });
  });

  group('SharingModule и библиотека', () {
    late AppDependencies dependencies;

    setUp(() {
      dependencies = AppDependencies(core: CoreModule(database: createInMemoryDatabase()));
    });

    tearDown(() => dependencies.dispose());

    test('сценарии обмена создаются заново, кубит обмена один на приложение', () {
      expect(dependencies.sharing.exportProjects(), isNot(same(dependencies.sharing.exportProjects())));
      expect(dependencies.sharing.importBiser(), isNot(same(dependencies.sharing.importBiser())));
      expect(dependencies.sharing.importOxs(), isNot(same(dependencies.sharing.importOxs())));
      expect(dependencies.sharing.dataTransferCubit, same(dependencies.sharing.dataTransferCubit));
      expect(dependencies.sharing.incomingFiles, same(dependencies.sharing.incomingFiles));
    });

    test('dispose закрывает созданный кубит обмена', () async {
      final DataTransferCubit cubit = dependencies.sharing.dataTransferCubit;

      await dependencies.dispose();

      expect(cubit.isClosed, isTrue);
    });

    test('реестры библиотеки создаются один раз, пункты «Нового проекта» уже заполнены', () {
      expect(dependencies.projects.newProjectRegistry, same(dependencies.projects.newProjectRegistry));
      expect(dependencies.projects.thumbnailRegistry, same(dependencies.projects.thumbnailRegistry));
      expect(dependencies.projects.newProjectRegistry.entriesFor(Craft.beading), isNotEmpty);
    });

    test('кубит библиотеки и сценарии удаления и копирования собираются со всеми фичами', () async {
      final LibraryCubit library = dependencies.projects.libraryCubit();

      expect(dependencies.projects.deleteProject(), isA<DeleteProject>());
      expect(dependencies.projects.duplicateProject(), isA<DuplicateProject>());
      expect(dependencies.grid.loadProjectPreview(), isA<LoadProjectPreview>());
      await library.close();
    });
  });
}

class _EmptyAssets implements CatalogAssetSource {
  @override
  Future<List<String>> listFiles() async => <String>[];

  @override
  Future<String> read(String path) async => '';
}
