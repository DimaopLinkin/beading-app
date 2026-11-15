import 'package:beading/app/composition/app_dependencies.dart';
import 'package:beading/app/composition/core_module.dart';
import 'package:beading/app/library_entries.dart';
import 'package:beading/app/platform/desktop_window.dart';
import 'package:beading/app/platform/orientation_lock.dart';
import 'package:beading/core/clock.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/sharing/drift_unit_of_work.dart';
import 'package:beading/data/sharing/file_picker_biser_picker.dart';
import 'package:beading/data/sharing/platform_incoming_biser_files.dart';
import 'package:beading/data/sharing/zip_biser_codec.dart';
import 'package:beading/data/stitch_import/xml_oxs_decoder.dart';
import 'package:beading/domain/bead_stock/bead_stock_repository.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/floss_stock/floss_stock_repository.dart';
import 'package:beading/domain/grid_pattern/cell_progress_store.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_content.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/grid_progress_store.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/image_pattern/book_work/book_work_repository.dart';
import 'package:beading/domain/image_pattern/book_work/record_book_progress.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/image_pattern/image_pattern_content.dart';
import 'package:beading/domain/image_pattern/image_pattern_repository.dart';
import 'package:beading/domain/printing/pattern_printer.dart';
import 'package:beading/domain/printing/use_cases/export_pattern_pdf.dart';
import 'package:beading/domain/projects/load_project_preview.dart';
import 'package:beading/domain/projects/project_content_cleaner.dart';
import 'package:beading/domain/projects/project_content_cloner.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/delete_project.dart';
import 'package:beading/domain/projects/use_cases/duplicate_project.dart';
import 'package:beading/domain/projects/use_cases/rename_project.dart';
import 'package:beading/domain/projects/use_cases/update_notes.dart';
import 'package:beading/domain/projects/use_cases/watch_projects.dart';
import 'package:beading/domain/settings/app_info.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:beading/domain/settings/keep_screen_awake_setting.dart';
import 'package:beading/domain/settings/reduce_transparency_source.dart';
import 'package:beading/domain/settings/screen_wake_lock.dart';
import 'package:beading/domain/settings/settings_repository.dart';
import 'package:beading/domain/settings/wakelock_controller.dart';
import 'package:beading/domain/sharing/biser/biser_codec.dart';
import 'package:beading/domain/sharing/biser/biser_file_source.dart';
import 'package:beading/domain/sharing/biser/export_projects.dart';
import 'package:beading/domain/sharing/biser/import_biser.dart';
import 'package:beading/domain/sharing/file_sharer.dart';
import 'package:beading/domain/sharing/unit_of_work.dart';
import 'package:beading/domain/stitch_import/import_oxs.dart';
import 'package:beading/domain/stitch_import/oxs_pattern.dart';
import 'package:beading/domain/weaving/work_session_content_cleaner.dart';
import 'package:beading/domain/weaving/work_session_repository.dart';
import 'package:beading/presentation/library/library_cubit.dart';
import 'package:beading/presentation/library/new_project_entry.dart';
import 'package:beading/presentation/library/project_thumbnail_provider.dart';
import 'package:beading/presentation/sharing/data_transfer_cubit.dart';
import 'package:get_it/get_it.dart';

/// Глобальный контейнер зависимостей. Регистрируем только здесь.
final GetIt getIt = GetIt.instance;

/// Регистрирует сервисы в [locator]. Вызывается один раз при запуске (и в каждом тесте заново):
/// повторный вызов сначала сбрасывает прежние регистрации.
///
/// [database] — готовая база (в тестах — в памяти); без неё открывается файл в Application Support.
Future<void> configureDependencies(
  AppDependencies dependencies, {
  GetIt? locator,
}) async {
  final GetIt container = locator ?? getIt;
  await container.reset();
  final CoreModule core = dependencies.core;
  final AppDatabase db = core.database;
  container
    ..registerSingleton<AppDatabase>(db, dispose: (_) => dependencies.dispose())
    ..registerLazySingleton<Clock>(() => core.clock)
    ..registerLazySingleton<IdGenerator>(() => core.ids)
    ..registerLazySingleton<DeviceIdProvider>(() => core.deviceIds)
    ..registerLazySingleton<SettingsRepository>(() => core.settings)
    ..registerLazySingleton<OrientationLock>(() => core.orientationLock)
    ..registerLazySingleton<DesktopWindow>(() => core.desktopWindow)
    ..registerLazySingleton<ScreenWakeLock>(() => core.screenWakeLock)
    ..registerLazySingleton<ReduceTransparencySource>(() => core.reduceTransparency)
    ..registerLazySingleton<KeepScreenAwakeSetting>(() => core.keepScreenAwake)
    ..registerLazySingleton<WakelockController>(() => core.wakelock)
    ..registerLazySingleton<AppEvents>(() => core.events)
    ..registerLazySingleton<FileStore>(() => core.fileStore)
    ..registerLazySingleton<ProjectRepository>(() => dependencies.projects.repository)
    ..registerFactory<CreateProject>(() => dependencies.projects.createProject())
    ..registerFactory<RenameProject>(() => dependencies.projects.renameProject())
    ..registerFactory<UpdateNotes>(() => dependencies.projects.updateNotes())
    ..registerFactory<WatchProjects>(() => dependencies.projects.watchProjects())
    ..registerFactory<RecordBookProgress>(() => dependencies.projects.recordBookProgress())
    ..registerLazySingleton<ImagePatternRepository>(() => dependencies.book.imagePatterns)
    ..registerLazySingleton<BookWorkRepository>(() => dependencies.book.bookWork)
    ..registerLazySingleton<ImagePatternContentCleaner>(() => dependencies.book.contentCleaner)
    ..registerLazySingleton<ImagePatternContentCloner>(() => dependencies.book.contentCloner)
    ..registerLazySingleton<GridPatternRepository>(() => dependencies.grid.patterns)
    ..registerLazySingleton<GridProgressStore>(() => dependencies.grid.progress)
    ..registerLazySingleton<CellProgressStore>(() => dependencies.grid.cellProgress)
    ..registerLazySingleton<GridPatternContentCleaner>(() => dependencies.grid.contentCleaner)
    ..registerLazySingleton<GridPatternContentCloner>(() => dependencies.grid.contentCloner)
    ..registerFactory<CreateGridPattern>(() => dependencies.grid.createGridPattern())
    ..registerLazySingleton<WorkSessionRepository>(() => dependencies.weaving.sessions)
    ..registerLazySingleton<WorkSessionContentCleaner>(() => dependencies.weaving.contentCleaner)
    ..registerFactory<DeleteProject>(
      () => DeleteProject(
        container<ProjectRepository>(),
        cleaners: <ProjectContentCleaner>[
          container<ImagePatternContentCleaner>(),
          container<GridPatternContentCleaner>(),
          dependencies.imageToGrid.contentCleaner,
          container<WorkSessionContentCleaner>(),
        ],
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
    ..registerLazySingleton<CatalogRepository>(() => dependencies.catalog.repository)
    ..registerLazySingleton<FlossStockRepository>(() => dependencies.catalog.flossStock)
    ..registerLazySingleton<BeadStockRepository>(() => dependencies.catalog.beadStock)
    ..registerLazySingleton<PatternPrinter>(() => dependencies.grid.printer)
    ..registerFactory<ExportPatternPdf>(() => dependencies.grid.exportPatternPdf())
    // Экспорт/импорт .biser и резервная копия (T21).
    ..registerLazySingleton<BiserCodec>(() => const ZipBiserCodec())
    ..registerLazySingleton<UnitOfWork>(() => DriftUnitOfWork(db))
    ..registerLazySingleton<FileSharer>(() => core.fileSharer)
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
        flossStock: container<FlossStockRepository>(),
        beadStock: container<BeadStockRepository>(),
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
        flossStock: container<FlossStockRepository>(),
        beadStock: container<BeadStockRepository>(),
      ),
    )
    ..registerLazySingleton<OxsDecoder>(() => const XmlOxsDecoder())
    ..registerFactory<ImportOxs>(
      () => ImportOxs(decoder: container<OxsDecoder>(), createPattern: container<CreateGridPattern>()),
    )
    ..registerLazySingleton<DataTransferCubit>(
      () => DataTransferCubit(
        export: container<ExportProjects>(),
        import: container<ImportBiser>(),
        sharer: container<FileSharer>(),
        picker: container<BiserFilePicker>(),
        importOxs: container<ImportOxs>(),
      ),
      dispose: (cubit) => cubit.close(),
    )
    ..registerLazySingleton<AppInfoProvider>(() => dependencies.settings.appInfo)
    // Реестры библиотеки: фичи (T06, T17, T23, T25) добавляют сюда пункты «Нового проекта» и превью карточек.
    ..registerLazySingleton<NewProjectRegistry>(() {
      final NewProjectRegistry registry = NewProjectRegistry();
      registerLibraryEntries(registry);
      return registry;
    })
    ..registerLazySingleton<ProjectThumbnailRegistry>(ProjectThumbnailRegistry.new)
    ..registerLazySingleton<LoadProjectPreview>(
      () => LoadProjectPreview(
        patterns: container<GridPatternRepository>(),
        rows: container<GridProgressStore>(),
        cells: container<CellProgressStore>(),
        files: container<FileStore>(),
      ),
    )
    ..registerFactory<LibraryCubit>(
      () => LibraryCubit(
        watchProjects: container<WatchProjects>(),
        deleteProject: container<DeleteProject>(),
        renameProject: container<RenameProject>(),
        duplicateProject: container<DuplicateProject>(),
      ),
    );
}
