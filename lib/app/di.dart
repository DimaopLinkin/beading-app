import 'dart:math';

import 'package:beading/app/library_entries.dart';
import 'package:beading/app/platform/desktop_window.dart';
import 'package:beading/app/platform/orientation_lock.dart';
import 'package:beading/core/clock.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/data/catalog/catalog_asset_source.dart';
import 'package:beading/data/catalog/catalog_seeder.dart';
import 'package:beading/data/catalog/drift_catalog_repository.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/open_database.dart';
import 'package:beading/data/easter_eggs/asset_compliment_source.dart';
import 'package:beading/data/easter_eggs/drift_easter_egg_log.dart';
import 'package:beading/data/grid_pattern/drift_cell_progress_store.dart';
import 'package:beading/data/grid_pattern/drift_grid_pattern_repository.dart';
import 'package:beading/data/grid_pattern/drift_grid_progress_store.dart';
import 'package:beading/data/image_pattern/drift_book_work_repository.dart';
import 'package:beading/data/image_pattern/drift_image_pattern_repository.dart';
import 'package:beading/data/image_pattern/local_file_store.dart';
import 'package:beading/data/image_pattern/pdfrx_pdf_rasterizer.dart';
import 'package:beading/data/image_pattern/picker_book_image_source.dart';
import 'package:beading/data/image_pattern/ui_image_processor.dart';
import 'package:beading/data/image_to_grid/isolate_image_to_grid_runner.dart';
import 'package:beading/data/image_to_grid/ui_image_decoder.dart';
import 'package:beading/data/platform/method_channel_image_masks.dart';
import 'package:beading/data/platform/method_channel_reduce_transparency_source.dart';
import 'package:beading/data/platform/share_plus_text_sharer.dart';
import 'package:beading/data/platform/wakelock_plus_screen_wake_lock.dart';
import 'package:beading/data/projects/drift_project_repository.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/data/settings/drift_settings_repository.dart';
import 'package:beading/data/settings/package_info_app_info_provider.dart';
import 'package:beading/data/settings/repository_keep_screen_awake_setting.dart';
import 'package:beading/data/sharing/drift_unit_of_work.dart';
import 'package:beading/data/sharing/file_picker_biser_picker.dart';
import 'package:beading/data/sharing/platform_incoming_biser_files.dart';
import 'package:beading/data/sharing/share_plus_file_sharer.dart';
import 'package:beading/data/sharing/zip_biser_codec.dart';
import 'package:beading/data/weaving/drift_work_session_repository.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/catalog/use_cases/find_similar_colors.dart';
import 'package:beading/domain/easter_eggs/compliment_source.dart';
import 'package:beading/domain/easter_eggs/easter_egg_log.dart';
import 'package:beading/domain/easter_eggs/easter_egg_policy.dart';
import 'package:beading/domain/easter_eggs/easter_egg_service.dart';
import 'package:beading/domain/easter_eggs/long_session_watcher.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/grid_pattern/cell_progress_store.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_content.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/grid_progress_store.dart';
import 'package:beading/domain/grid_pattern/use_cases/cell_progress_commands.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/grid_pattern/use_cases/grid_progress_commands.dart';
import 'package:beading/domain/grid_pattern/use_cases/save_grid_pattern.dart';
import 'package:beading/domain/image_pattern/book_work/book_work_repository.dart';
import 'package:beading/domain/image_pattern/book_work/record_book_progress.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/image_pattern/image_pattern_content.dart';
import 'package:beading/domain/image_pattern/image_pattern_repository.dart';
import 'package:beading/domain/image_pattern/image_processor.dart';
import 'package:beading/domain/image_pattern/pdf_rasterizer.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/image_pattern/use_cases/import_book_pattern.dart';
import 'package:beading/domain/image_to_grid/image_decoder.dart';
import 'package:beading/domain/image_to_grid/image_masks.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_runner.dart';
import 'package:beading/domain/image_to_grid/use_cases/create_pattern_from_image.dart';
import 'package:beading/domain/materials/use_cases/load_project_floss.dart';
import 'package:beading/domain/materials/use_cases/load_project_materials.dart';
import 'package:beading/domain/projects/project_content_cleaner.dart';
import 'package:beading/domain/projects/project_content_cloner.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/change_project_status.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/delete_project.dart';
import 'package:beading/domain/projects/use_cases/duplicate_project.dart';
import 'package:beading/domain/projects/use_cases/rename_project.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:beading/domain/projects/use_cases/update_notes.dart';
import 'package:beading/domain/projects/use_cases/watch_projects.dart';
import 'package:beading/domain/settings/app_events_secret_tap_handler.dart';
import 'package:beading/domain/settings/app_info.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:beading/domain/settings/keep_screen_awake_setting.dart';
import 'package:beading/domain/settings/reduce_transparency_source.dart';
import 'package:beading/domain/settings/screen_wake_lock.dart';
import 'package:beading/domain/settings/secret_tap_handler.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/settings_repository.dart';
import 'package:beading/domain/settings/wakelock_controller.dart';
import 'package:beading/domain/sharing/biser/biser_codec.dart';
import 'package:beading/domain/sharing/biser/biser_file_source.dart';
import 'package:beading/domain/sharing/biser/export_projects.dart';
import 'package:beading/domain/sharing/biser/import_biser.dart';
import 'package:beading/domain/sharing/file_sharer.dart';
import 'package:beading/domain/sharing/text_sharer.dart';
import 'package:beading/domain/sharing/unit_of_work.dart';
import 'package:beading/domain/weaving/rows_counter.dart';
import 'package:beading/domain/weaving/work_session_content_cleaner.dart';
import 'package:beading/domain/weaving/work_session_repository.dart';
import 'package:beading/domain/weaving/work_session_tracker.dart';
import 'package:beading/presentation/book_work/book_work_cubit.dart';
import 'package:beading/presentation/catalog/catalog_cubit.dart';
import 'package:beading/presentation/easter_eggs/compliment_banner_cubit.dart';
import 'package:beading/presentation/editor/editor_cubit.dart';
import 'package:beading/presentation/editor/new_grid_cubit.dart';
import 'package:beading/presentation/editor/new_stitch_cubit.dart';
import 'package:beading/presentation/floss/floss_cubit.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_cubit.dart';
import 'package:beading/presentation/import_book/import_book_cubit.dart';
import 'package:beading/presentation/library/library_cubit.dart';
import 'package:beading/presentation/library/new_project_entry.dart';
import 'package:beading/presentation/library/project_thumbnail_provider.dart';
import 'package:beading/presentation/materials/materials_cubit.dart';
import 'package:beading/presentation/pattern_template/pattern_template_cubit.dart';
import 'package:beading/presentation/settings/settings_cubit.dart';
import 'package:beading/presentation/sharing/data_transfer_cubit.dart';
import 'package:beading/presentation/theme/theme_mode_cubit.dart';
import 'package:beading/presentation/weaving/weave_cubit.dart';
import 'package:get_it/get_it.dart';

/// Глобальный контейнер зависимостей. Регистрируем только здесь.
final GetIt getIt = GetIt.instance;

/// Регистрирует сервисы в [locator]. Вызывается один раз при запуске (и в каждом тесте заново):
/// повторный вызов сначала сбрасывает прежние регистрации.
///
/// [database] — готовая база (в тестах — в памяти); без неё открывается файл в Application Support.
/// [catalogAssets] подменяет файлы каталога (в тестах).
/// Длинная сторона картинки в мастере «картинка → схема», пикселей.
const int _wizardImageMaxSide = 2048;

Future<void> configureDependencies({GetIt? locator, AppDatabase? database, CatalogAssetSource? catalogAssets}) async {
  final GetIt container = locator ?? getIt;
  await container.reset();
  final AppDatabase db = database ?? await openAppDatabase();
  container
    ..registerSingleton<AppDatabase>(db, dispose: (value) => value.close())
    ..registerLazySingleton<Clock>(SystemClock.new)
    ..registerLazySingleton<IdGenerator>(() => UuidV7IdGenerator(clock: container<Clock>()))
    ..registerLazySingleton<DeviceIdProvider>(
      () => DriftDeviceIdProvider(dao: db.settingsDao, ids: container<IdGenerator>(), clock: container<Clock>()),
    )
    ..registerLazySingleton<SettingsRepository>(
      () => DriftSettingsRepository(
        dao: db.settingsDao,
        deviceIds: container<DeviceIdProvider>(),
        clock: container<Clock>(),
      ),
    )
    ..registerLazySingleton<OrientationLock>(SystemChromeOrientationLock.new)
    ..registerLazySingleton<DesktopWindow>(WindowManagerDesktopWindow.new)
    ..registerLazySingleton<ScreenWakeLock>(WakelockPlusScreenWakeLock.new)
    ..registerLazySingleton<ReduceTransparencySource>(
      MethodChannelReduceTransparencySource.new,
      dispose: (source) async {
        if (source is MethodChannelReduceTransparencySource) {
          await source.dispose();
        }
      },
    )
    ..registerLazySingleton<KeepScreenAwakeSetting>(
      () => RepositoryKeepScreenAwakeSetting(container<SettingsRepository>()),
    )
    ..registerLazySingleton<WakelockController>(
      () => WakelockController(wakeLock: container<ScreenWakeLock>(), setting: container<KeepScreenAwakeSetting>()),
    )
    ..registerLazySingleton<AppEvents>(
      BroadcastAppEvents.new,
      dispose: (events) => (events as BroadcastAppEvents).dispose(),
    )
    ..registerLazySingleton<ProjectRepository>(
      () => DriftProjectRepository(
        dao: db.projectsDao,
        deviceIds: container<DeviceIdProvider>(),
        clock: container<Clock>(),
      ),
    )
    ..registerFactory<CreateProject>(
      () => CreateProject(
        repository: container<ProjectRepository>(),
        ids: container<IdGenerator>(),
        clock: container<Clock>(),
      ),
    )
    ..registerFactory<RenameProject>(() => RenameProject(container<ProjectRepository>()))
    ..registerFactory<UpdateNotes>(() => UpdateNotes(container<ProjectRepository>()))
    ..registerLazySingleton<FileStore>(LocalFileStore.applicationSupport)
    ..registerLazySingleton<ImageProcessor>(UiImageProcessor.new)
    ..registerLazySingleton<ImageToGridRunner>(IsolateImageToGridRunner.new)
    ..registerLazySingleton<PdfRasterizer>(PdfrxPdfRasterizer.new)
    ..registerLazySingleton<BookImageSource>(PickerBookImageSource.new)
    ..registerLazySingleton<ImagePatternRepository>(
      () => DriftImagePatternRepository(
        dao: db.imagePatternsDao,
        deviceIds: container<DeviceIdProvider>(),
        clock: container<Clock>(),
      ),
    )
    ..registerLazySingleton<ImagePatternContentCleaner>(
      () => ImagePatternContentCleaner(
        patterns: container<ImagePatternRepository>(),
        files: container<FileStore>(),
      ),
    )
    ..registerLazySingleton<ImagePatternContentCloner>(
      () => ImagePatternContentCloner(
        patterns: container<ImagePatternRepository>(),
        projects: container<ProjectRepository>(),
        files: container<FileStore>(),
        ids: container<IdGenerator>(),
      ),
    )
    ..registerFactory<ImportBookPattern>(
      () => ImportBookPattern(
        createProject: container<CreateProject>(),
        projects: container<ProjectRepository>(),
        patterns: container<ImagePatternRepository>(),
        processor: container<ImageProcessor>(),
        files: container<FileStore>(),
        ids: container<IdGenerator>(),
      ),
    )
    ..registerFactory<ImportBookCubit>(
      () => ImportBookCubit(
        source: container<BookImageSource>(),
        rasterizer: container<PdfRasterizer>(),
        importBookPattern: container<ImportBookPattern>(),
      ),
    )
    ..registerLazySingleton<ImageDecoder>(UiImageDecoder.new)
    ..registerLazySingleton<ImageMasks>(MethodChannelImageMasks.new)
    ..registerFactory<ImageWizardCubit>(
      () => ImageWizardCubit(
        source: container<BookImageSource>(),
        // Генератору хватает 2048: поворот и обрезка отзываются быстрее, пик памяти и маска Vision меньше. Книги — 4096.
        processor: const UiImageProcessor(maxSide: _wizardImageMaxSide),
        decoder: container<ImageDecoder>(),
        runner: container<ImageToGridRunner>(),
        masks: container<ImageMasks>(),
        catalog: container<CatalogRepository>(),
        settings: container<SettingsRepository>(),
        createPattern: CreatePatternFromImage(container<CreateGridPattern>()),
        sizeHints: true,
      ),
    )
    ..registerLazySingleton<GridPatternRepository>(
      () => DriftGridPatternRepository(
        dao: db.gridPatternsDao,
        deviceIds: container<DeviceIdProvider>(),
        clock: container<Clock>(),
        ids: container<IdGenerator>(),
      ),
    )
    ..registerLazySingleton<GridProgressStore>(
      () => DriftGridProgressStore(
        dao: db.gridPatternsDao,
        deviceIds: container<DeviceIdProvider>(),
        clock: container<Clock>(),
        ids: container<IdGenerator>(),
      ),
    )
    ..registerLazySingleton<CellProgressStore>(
      () => DriftCellProgressStore(
        dao: db.gridPatternsDao,
        deviceIds: container<DeviceIdProvider>(),
        clock: container<Clock>(),
        ids: container<IdGenerator>(),
      ),
    )
    ..registerFactory<MarkCells>(
      () => MarkCells(patterns: container<GridPatternRepository>(), progress: container<CellProgressStore>()),
    )
    ..registerFactory<MarkRect>(
      () => MarkRect(patterns: container<GridPatternRepository>(), progress: container<CellProgressStore>()),
    )
    ..registerFactory<MarkColor>(
      () => MarkColor(patterns: container<GridPatternRepository>(), progress: container<CellProgressStore>()),
    )
    ..registerLazySingleton<GridPatternContentCleaner>(
      () => GridPatternContentCleaner(container<GridPatternRepository>()),
    )
    ..registerLazySingleton<GridPatternContentCloner>(
      () => GridPatternContentCloner(patterns: container<GridPatternRepository>(), ids: container<IdGenerator>()),
    )
    ..registerFactory<CreateGridPattern>(
      () => CreateGridPattern(
        createProject: container<CreateProject>(),
        projects: container<ProjectRepository>(),
        patterns: container<GridPatternRepository>(),
        ids: container<IdGenerator>(),
      ),
    )
    ..registerFactory<SaveGridPattern>(() => SaveGridPattern(container<GridPatternRepository>()))
    ..registerFactory<MarkRow>(
      () => MarkRow(patterns: container<GridPatternRepository>(), progress: container<GridProgressStore>()),
    )
    ..registerFactory<UnmarkRow>(
      () => UnmarkRow(patterns: container<GridPatternRepository>(), progress: container<GridProgressStore>()),
    )
    ..registerFactory<SetCurrentBead>(
      () => SetCurrentBead(patterns: container<GridPatternRepository>(), progress: container<GridProgressStore>()),
    )
    ..registerLazySingleton<BookWorkRepository>(
      () => DriftBookWorkRepository(
        dao: db.bookWorkDao,
        deviceIds: container<DeviceIdProvider>(),
        clock: container<Clock>(),
      ),
    )
    ..registerFactory<DeleteProject>(
      () => DeleteProject(
        container<ProjectRepository>(),
        cleaners: <ProjectContentCleaner>[
          container<ImagePatternContentCleaner>(),
          container<GridPatternContentCleaner>(),
          container<WorkSessionContentCleaner>(),
        ],
      ),
    )
    ..registerFactory<WatchProjects>(() => WatchProjects(container<ProjectRepository>()))
    ..registerFactory<TouchProject>(
      () => TouchProject(repository: container<ProjectRepository>(), clock: container<Clock>()),
    )
    ..registerFactory<ChangeProjectStatus>(
      () => ChangeProjectStatus(repository: container<ProjectRepository>(), events: container<AppEvents>()),
    )
    // Клонеры содержимого: схемы-картинки (T06) и сетки (T14).
    ..registerFactory<RecordBookProgress>(
      () => RecordBookProgress(
        projects: container<ProjectRepository>(),
        changeStatus: container<ChangeProjectStatus>(),
        touch: container<TouchProject>(),
      ),
    )
    ..registerFactoryParam<EditorCubit, String, void>(
      (projectId, _) => EditorCubit(
        projectId: projectId,
        projects: container<ProjectRepository>(),
        patterns: container<GridPatternRepository>(),
        savePattern: container<SaveGridPattern>(),
        touchProject: container<TouchProject>(),
        catalog: container<CatalogRepository>(),
      ),
    )
    ..registerFactoryParam<NewGridCubit, String, void>(
      (defaultName, _) => NewGridCubit(createPattern: container<CreateGridPattern>(), defaultName: defaultName),
    )
    ..registerFactoryParam<NewStitchCubit, String, void>(
      (defaultName, _) => NewStitchCubit(createPattern: container<CreateGridPattern>(), defaultName: defaultName),
    )
    ..registerFactoryParam<BookWorkCubit, String, void>(
      (projectId, _) => BookWorkCubit(
        projectId: projectId,
        projects: container<ProjectRepository>(),
        patterns: container<ImagePatternRepository>(),
        work: container<BookWorkRepository>(),
        recordProgress: container<RecordBookProgress>(),
        updateNotes: container<UpdateNotes>(),
      ),
    )
    ..registerLazySingleton<WorkSessionRepository>(
      () => DriftWorkSessionRepository(
        dao: db.workSessionsDao,
        deviceIds: container<DeviceIdProvider>(),
        clock: container<Clock>(),
        ids: container<IdGenerator>(),
      ),
    )
    ..registerLazySingleton<WorkSessionContentCleaner>(
      () => WorkSessionContentCleaner(container<WorkSessionRepository>()),
    )
    ..registerFactory<RowsCounter>(
      () => RowsCounter(settings: container<SettingsRepository>(), events: container<AppEvents>()),
    )
    // Отдельный счётчик времени на каждый экран плетения.
    ..registerFactory<WorkSessionTracker>(
      () => WorkSessionTracker(
        sessions: container<WorkSessionRepository>(),
        clock: container<Clock>(),
      ),
    )
    ..registerFactoryParam<WeaveCubit, String, void>(
      (projectId, _) => WeaveCubit(
        projectId: projectId,
        projects: container<ProjectRepository>(),
        patterns: container<GridPatternRepository>(),
        progress: container<GridProgressStore>(),
        settings: container<SettingsRepository>(),
        recordProgress: container<RecordBookProgress>(),
        changeStatus: container<ChangeProjectStatus>(),
        rowsCounter: container<RowsCounter>(),
        tracker: container<WorkSessionTracker>(),
      ),
    )
    ..registerFactory<DuplicateProject>(
      () => DuplicateProject(
        repository: container<ProjectRepository>(),
        ids: container<IdGenerator>(),
        clock: container<Clock>(),
        cloners: <ProjectContentCloner>[
          container<ImagePatternContentCloner>(),
          container<GridPatternContentCloner>(),
        ],
      ),
    )
    ..registerLazySingleton<EasterEggLog>(() => DriftEasterEggLog(db.easterEggLogDao))
    ..registerLazySingleton<ComplimentSource>(AssetComplimentSource.new)
    ..registerLazySingleton<EasterEggService>(
      () => EasterEggService(
        events: container<AppEvents>(),
        // Композиционный корень: единственное место, где создаётся источник случайности пасхалок.
        policy: EasterEggPolicy(random: Random()),
        log: container<EasterEggLog>(),
        source: container<ComplimentSource>(),
        settings: container<SettingsRepository>(),
        clock: container<Clock>(),
      ),
      dispose: (value) => value.dispose(),
    )
    ..registerLazySingleton<LongSessionWatcher>(
      () => LongSessionWatcher(events: container<AppEvents>(), clock: container<Clock>()),
      dispose: (value) => value.dispose(),
    )
    ..registerFactory<ComplimentBannerCubit>(() => ComplimentBannerCubit(container<EasterEggService>().shown))
    ..registerLazySingleton<CatalogAssetSource>(() => catalogAssets ?? BundleCatalogAssetSource())
    ..registerLazySingleton<CatalogSeeder>(
      () => CatalogSeeder(dao: db.catalogDao, assets: container<CatalogAssetSource>()),
    )
    ..registerLazySingleton<CatalogRepository>(() => DriftCatalogRepository(db.catalogDao))
    ..registerFactory<FindSimilarColors>(() => FindSimilarColors(container<CatalogRepository>()))
    ..registerFactory<CatalogCubit>(
      () => CatalogCubit(
        catalog: container<CatalogRepository>(),
        findSimilar: container<FindSimilarColors>(),
        settings: container<SettingsRepository>(),
        brandSetting: SettingKeys.defaultBeadBrand,
      ),
    )
    ..registerFactory<PatternTemplateCubit>(
      () => PatternTemplateCubit(
        catalog: container<CatalogRepository>(),
        settings: container<SettingsRepository>(),
        createPattern: container<CreateGridPattern>(),
        brandSetting: SettingKeys.defaultBeadBrand,
      ),
    )
    ..registerLazySingleton<TextSharer>(SharePlusTextSharer.new)
    ..registerFactory<LoadProjectMaterials>(() => LoadProjectMaterials(container<GridPatternRepository>()))
    ..registerFactory<LoadProjectFloss>(() => LoadProjectFloss(container<GridPatternRepository>()))
    ..registerFactoryParam<FlossCubit, String, void>(
      (projectId, _) => FlossCubit(
        projectId: projectId,
        loadFloss: container<LoadProjectFloss>(),
        projects: container<ProjectRepository>(),
      ),
    )
    ..registerFactoryParam<MaterialsCubit, String, void>(
      (projectId, _) => MaterialsCubit(
        projectId: projectId,
        loadMaterials: container<LoadProjectMaterials>(),
        projects: container<ProjectRepository>(),
      ),
    )
    // Экспорт/импорт .biser и резервная копия (T21).
    ..registerLazySingleton<BiserCodec>(() => const ZipBiserCodec())
    ..registerLazySingleton<UnitOfWork>(() => DriftUnitOfWork(db))
    ..registerLazySingleton<FileSharer>(SharePlusFileSharer.new)
    ..registerLazySingleton<BiserFilePicker>(() => const FilePickerBiserPicker())
    ..registerLazySingleton<IncomingBiserFiles>(PlatformIncomingBiserFiles.new)
    ..registerFactory<ExportProjects>(
      () => ExportProjects(
        projects: container<ProjectRepository>(),
        grids: container<GridPatternRepository>(),
        progress: container<GridProgressStore>(),
        cellProgress: container<CellProgressStore>(),
        images: container<ImagePatternRepository>(),
        bookWork: container<BookWorkRepository>(),
        workSessions: container<WorkSessionRepository>(),
        files: container<FileStore>(),
        codec: container<BiserCodec>(),
        clock: container<Clock>(),
        appInfo: container<AppInfoProvider>(),
      ),
    )
    ..registerFactory<ImportBiser>(
      () => ImportBiser(
        codec: container<BiserCodec>(),
        projects: container<ProjectRepository>(),
        grids: container<GridPatternRepository>(),
        progress: container<GridProgressStore>(),
        cellProgress: container<CellProgressStore>(),
        images: container<ImagePatternRepository>(),
        bookWork: container<BookWorkRepository>(),
        workSessions: container<WorkSessionRepository>(),
        files: container<FileStore>(),
        ids: container<IdGenerator>(),
        unitOfWork: container<UnitOfWork>(),
      ),
    )
    ..registerLazySingleton<DataTransferCubit>(
      () => DataTransferCubit(
        export: container<ExportProjects>(),
        import: container<ImportBiser>(),
        sharer: container<FileSharer>(),
        picker: container<BiserFilePicker>(),
      ),
      dispose: (cubit) => cubit.close(),
    )
    ..registerFactory<ThemeModeCubit>(() => ThemeModeCubit(container<SettingsRepository>()))
    ..registerFactory<SettingsCubit>(() => SettingsCubit(container<SettingsRepository>()))
    ..registerLazySingleton<AppInfoProvider>(PackageInfoAppInfoProvider.new)
    ..registerLazySingleton<SecretTapHandler>(() => AppEventsSecretTapHandler(container<AppEvents>()))
    // Реестры библиотеки: фичи (T06, T17, T23, T25) добавляют сюда пункты «Нового проекта» и превью карточек.
    ..registerLazySingleton<NewProjectRegistry>(() {
      final NewProjectRegistry registry = NewProjectRegistry();
      registerLibraryEntries(registry);
      return registry;
    })
    ..registerLazySingleton<ProjectThumbnailRegistry>(ProjectThumbnailRegistry.new)
    ..registerFactory<LibraryCubit>(
      () => LibraryCubit(
        watchProjects: container<WatchProjects>(),
        deleteProject: container<DeleteProject>(),
        renameProject: container<RenameProject>(),
        duplicateProject: container<DuplicateProject>(),
      ),
    );
}
