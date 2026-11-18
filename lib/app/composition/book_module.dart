import 'package:beading/app/composition/app_routes.dart';
import 'package:beading/app/composition/core_module.dart';
import 'package:beading/app/composition/projects_module.dart';
import 'package:beading/data/image_pattern/drift_book_work_repository.dart';
import 'package:beading/data/image_pattern/drift_image_pattern_repository.dart';
import 'package:beading/data/image_pattern/pdfrx_pdf_rasterizer.dart';
import 'package:beading/data/image_pattern/picker_book_image_source.dart';
import 'package:beading/data/image_pattern/ui_image_processor.dart';
import 'package:beading/domain/image_pattern/book_work/book_work_repository.dart';
import 'package:beading/domain/image_pattern/image_pattern_content.dart';
import 'package:beading/domain/image_pattern/image_pattern_repository.dart';
import 'package:beading/domain/image_pattern/use_cases/import_book_pattern.dart';
import 'package:beading/presentation/book_work/book_work_cubit.dart';
import 'package:beading/presentation/book_work/book_work_screen.dart';
import 'package:beading/presentation/import_book/import_book_cubit.dart';
import 'package:beading/presentation/import_book/import_book_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Схемы из книг: импорт фото и PDF, работа по странице с линейкой (ADR-0007).
final class BookModule {
  BookModule({required CoreModule core, required ProjectsModule projects}) : _core = core, _projects = projects;

  final CoreModule _core;
  final ProjectsModule _projects;

  late final ImagePatternRepository imagePatterns = DriftImagePatternRepository(
    dao: _core.database.imagePatternsDao,
    deviceIds: _core.deviceIds,
    clock: _core.clock,
  );

  late final BookWorkRepository bookWork = DriftBookWorkRepository(
    dao: _core.database.bookWorkDao,
    deviceIds: _core.deviceIds,
    clock: _core.clock,
  );

  late final ImagePatternContentCleaner contentCleaner = ImagePatternContentCleaner(
    patterns: imagePatterns,
    files: _core.fileStore,
  );

  late final ImagePatternContentCloner contentCloner = ImagePatternContentCloner(
    patterns: imagePatterns,
    projects: _projects.repository,
    files: _core.fileStore,
    ids: _core.ids,
  );

  ImportBookPattern importBookPattern() => ImportBookPattern(
    createProject: _projects.createProject(),
    projects: _projects.repository,
    patterns: imagePatterns,
    processor: const UiImageProcessor(),
    files: _core.fileStore,
    ids: _core.ids,
  );

  /// Выбор файла и растеризатор PDF живут, пока открыт экран импорта.
  ImportBookCubit importBookCubit() => ImportBookCubit(
    source: PickerBookImageSource(),
    rasterizer: PdfrxPdfRasterizer(),
    importBookPattern: importBookPattern(),
  );

  BookWorkCubit bookWorkCubit(String projectId) => BookWorkCubit(
    projectId: projectId,
    projects: _projects.repository,
    patterns: imagePatterns,
    work: bookWork,
    recordProgress: _projects.recordBookProgress(),
    updateNotes: _projects.updateNotes(),
  );

  List<RouteBase> routes() => <RouteBase>[
    GoRoute(
      path: AppRoutes.importBook,
      builder: (_, _) => BlocProvider<ImportBookCubit>(
        create: (_) => importBookCubit(),
        child: const ImportBookScreen(),
      ),
    ),
    GoRoute(
      path: BookWorkScreen.routePath,
      builder: (_, state) => BlocProvider<BookWorkCubit>(
        create: (_) => bookWorkCubit(state.pathParameters['projectId']!)..load(),
        child: BookWorkScreen(files: _core.fileStore),
      ),
    ),
  ];
}
