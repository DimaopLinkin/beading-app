import 'dart:async';

import 'package:beading/app/composition/app_dependencies.dart';
import 'package:beading/app/composition/app_routes.dart';
import 'package:beading/app/di.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/image_pattern/pdf_rasterizer.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/load_project_preview.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/sharing/file_sharer.dart';
import 'package:beading/presentation/book_work/book_work_cubit.dart';
import 'package:beading/presentation/book_work/book_work_screen.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_cubit.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_screen.dart';
import 'package:beading/presentation/import_book/import_book_cubit.dart';
import 'package:beading/presentation/import_book/import_book_screen.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/library_cubit.dart';
import 'package:beading/presentation/library/library_screen.dart';
import 'package:beading/presentation/library/new_project_entry.dart';
import 'package:beading/presentation/library/project_thumbnail_provider.dart';
import 'package:beading/presentation/sharing/data_transfer_cubit.dart';
import 'package:beading/presentation/sharing/share_origin.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

export 'package:beading/app/composition/app_routes.dart';

/// Какой каталог открыть: бисер или нитки. Выбор — родной лист действий.
Future<void> _chooseCatalog(BuildContext context) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final String? route = await showCupertinoModalPopup<String>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      actions: <Widget>[
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(AppRoutes.catalog),
          child: Text(l10n.catalogTitleBead),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(AppRoutes.flossCatalog),
          child: Text(l10n.catalogTitleFloss),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: Text(l10n.cancel),
      ),
    ),
  );
  if (route != null && context.mounted) unawaited(context.push<void>(route));
}

/// Все страницы настроек делят [SettingsCubit] из корня приложения ([BeadingApp]).
///
/// [showDeveloperTools] — раздел «Для разработки» (проверка стекла); по умолчанию только вне релизной сборки.
GoRouter createRouter(AppDependencies dependencies, {bool showDeveloperTools = !kReleaseMode}) => GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.library,
      builder: (context, _) => BlocProvider<LibraryCubit>(
        create: (_) => getIt<LibraryCubit>()..start(),
        child: LibraryScreen(
          newProjects: getIt<NewProjectRegistry>(),
          thumbnails: getIt<ProjectThumbnailRegistry>(),
          loadPreview: getIt<LoadProjectPreview>(),
          onOpenSettings: () => context.push(AppRoutes.settings),
          onOpenCatalog: () => unawaited(_chooseCatalog(context)),
          onEditInGenerator: (context, project) => unawaited(_editInGenerator(context, project)),
          onOpenMaterials: (context, project) => context.push(
            project.craft == Craft.crossStitch ? AppRoutes.floss(project.id) : AppRoutes.materials(project.id),
          ),
          onShareFile: (context, project) => unawaited(
            getIt<DataTransferCubit>().shareProject(project.id, origin: shareOriginOf(context)),
          ),
          onOpenProject: (context, project) {
            switch (project.contentKind) {
              case ContentKind.image:
                unawaited(context.push<void>(AppRoutes.bookWork(project.id)));
              case ContentKind.grid:
                unawaited(
                  context.push<void>(
                    project.craft == Craft.crossStitch ? AppRoutes.stitch(project.id) : AppRoutes.weave(project.id),
                  ),
                );
              case ContentKind.steps:
                break;
            }
          },
        ),
      ),
    ),
    ...dependencies.settings.routes(
      showDeveloperTools: showDeveloperTools,
      dataTransfer: getIt.call,
      sync: dependencies.sync,
    ),
    GoRoute(
      path: AppRoutes.importBook,
      builder: (_, _) => BlocProvider<ImportBookCubit>(
        create: (_) => getIt<ImportBookCubit>(),
        child: const ImportBookScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.imageToGrid,
      builder: (_, state) => BlocProvider<ImageWizardCubit>(
        create: (_) {
          final ImageWizardCubit cubit = getIt<ImageWizardCubit>();
          final String? edit = state.uri.queryParameters['edit'];
          if (edit != null) {
            unawaited(cubit.startEditing(edit));
          } else {
            unawaited(
              cubit.start(
                craft: state.uri.queryParameters['craft'] == Craft.crossStitch.name ? Craft.crossStitch : Craft.beading,
              ),
            );
          }
          return cubit;
        },
        child: ImageWizardScreen(fileSharer: getIt<FileSharer>(), rasterizer: getIt<PdfRasterizer>()),
      ),
    ),
    ...dependencies.catalog.routes(),
    ...dependencies.grid.routes(),
    ...dependencies.weaving.routes(),
    ...dependencies.stitching.routes(),
    GoRoute(
      path: BookWorkScreen.routePath,
      builder: (_, state) => BlocProvider<BookWorkCubit>(
        create: (_) => getIt<BookWorkCubit>(param1: state.pathParameters['projectId'])..load(),
        child: BookWorkScreen(files: getIt<FileStore>()),
      ),
    ),
  ],
);

/// Открывает схему проекта в мастере «Схема из картинки»; сохранённую схему сразу показывает в редакторе.
Future<void> _editInGenerator(BuildContext context, Project project) async {
  final String? projectId = await context.push<String>('${AppRoutes.imageToGrid}?edit=${project.id}');
  if (projectId != null && context.mounted) {
    await context.push<void>(AppRoutes.editor(projectId));
  }
}
