import 'package:beading/app/composition/book_module.dart';
import 'package:beading/app/composition/catalog_module.dart';
import 'package:beading/app/composition/core_module.dart';
import 'package:beading/app/composition/grid_module.dart';
import 'package:beading/app/composition/projects_module.dart';
import 'package:beading/app/composition/settings_module.dart';
import 'package:beading/app/composition/steps_module.dart';
import 'package:beading/app/composition/weaving_module.dart';
import 'package:beading/data/sharing/drift_unit_of_work.dart';
import 'package:beading/data/sharing/file_picker_biser_picker.dart';
import 'package:beading/data/sharing/platform_incoming_biser_files.dart';
import 'package:beading/data/sharing/zip_biser_codec.dart';
import 'package:beading/data/stitch_import/xml_oxs_decoder.dart';
import 'package:beading/domain/sharing/biser/biser_codec.dart';
import 'package:beading/domain/sharing/biser/biser_file_source.dart';
import 'package:beading/domain/sharing/biser/export_projects.dart';
import 'package:beading/domain/sharing/biser/import_biser.dart';
import 'package:beading/domain/sharing/unit_of_work.dart';
import 'package:beading/domain/stitch_import/import_oxs.dart';
import 'package:beading/domain/stitch_import/oxs_pattern.dart';
import 'package:beading/presentation/sharing/data_transfer_cubit.dart';

/// Обмен файлами: экспорт и импорт `.biser`, резервная копия, импорт `.oxs` (ADR-0007).
final class SharingModule {
  SharingModule({
    required CoreModule core,
    required ProjectsModule projects,
    required GridModule grid,
    required BookModule book,
    required WeavingModule weaving,
    required CatalogModule catalog,
    required SettingsModule settings,
    required StepsModule steps,
  }) : _steps = steps,
       _core = core,
       _projects = projects,
       _grid = grid,
       _book = book,
       _weaving = weaving,
       _catalog = catalog,
       _settings = settings;

  final CoreModule _core;
  final ProjectsModule _projects;
  final GridModule _grid;
  final BookModule _book;
  final WeavingModule _weaving;
  final CatalogModule _catalog;
  final SettingsModule _settings;
  final StepsModule _steps;

  final BiserCodec codec = const ZipBiserCodec();

  final BiserFilePicker picker = const FilePickerBiserPicker();

  late final UnitOfWork unitOfWork = DriftUnitOfWork(_core.database);

  late final IncomingBiserFiles incomingFiles = PlatformIncomingBiserFiles();

  final OxsDecoder oxsDecoder = const XmlOxsDecoder();

  ExportProjects exportProjects() => ExportProjects(
    projects: _projects.repository,
    grids: _grid.patterns,
    progress: _grid.progress,
    cellProgress: _grid.cellProgress,
    images: _book.imagePatterns,
    bookWork: _book.bookWork,
    workSessions: _weaving.sessions,
    files: _core.fileStore,
    codec: codec,
    clock: _core.clock,
    appInfo: _settings.appInfo,
    flossStock: _catalog.flossStock,
    beadStock: _catalog.beadStock,
    steps: _steps.patterns,
    stepsProgress: _steps.progress,
  );

  ImportBiser importBiser() => ImportBiser(
    codec: codec,
    projects: _projects.repository,
    grids: _grid.patterns,
    progress: _grid.progress,
    cellProgress: _grid.cellProgress,
    images: _book.imagePatterns,
    bookWork: _book.bookWork,
    workSessions: _weaving.sessions,
    files: _core.fileStore,
    ids: _core.ids,
    unitOfWork: unitOfWork,
    flossStock: _catalog.flossStock,
    beadStock: _catalog.beadStock,
    steps: _steps.patterns,
    stepsProgress: _steps.progress,
  );

  ImportOxs importOxs() => ImportOxs(decoder: oxsDecoder, createPattern: _grid.createGridPattern());

  DataTransferCubit? _dataTransfer;

  /// Один на всё приложение: его слушает корневой хост обмена файлами. Закрывается в [dispose].
  DataTransferCubit get dataTransferCubit => _dataTransfer ??= DataTransferCubit(
    export: exportProjects(),
    import: importBiser(),
    sharer: _core.fileSharer,
    picker: picker,
    importOxs: importOxs(),
  );

  Future<void> dispose() async {
    await _dataTransfer?.close();
  }
}
