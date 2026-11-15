import 'dart:async';

import 'package:beading/app/composition/app_routes.dart';
import 'package:beading/app/composition/catalog_module.dart';
import 'package:beading/app/composition/core_module.dart';
import 'package:beading/app/composition/grid_module.dart';
import 'package:beading/app/composition/projects_module.dart';
import 'package:beading/data/image_pattern/pdfrx_pdf_rasterizer.dart';
import 'package:beading/data/image_pattern/picker_book_image_source.dart';
import 'package:beading/data/image_pattern/ui_image_processor.dart';
import 'package:beading/data/image_to_grid/isolate_image_to_grid_runner.dart';
import 'package:beading/data/image_to_grid/ui_image_decoder.dart';
import 'package:beading/data/platform/method_channel_image_masks.dart';
import 'package:beading/domain/image_to_grid/image_decoder.dart';
import 'package:beading/domain/image_to_grid/image_recipe.dart';
import 'package:beading/domain/image_to_grid/use_cases/create_pattern_from_image.dart';
import 'package:beading/domain/image_to_grid/use_cases/replace_pattern_from_image.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_cubit.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Мастер «картинка → схема» (ADR-0007).
final class ImageToGridModule {
  ImageToGridModule({
    required CoreModule core,
    required ProjectsModule projects,
    required GridModule grid,
    required CatalogModule catalog,
  }) : _core = core,
       _projects = projects,
       _grid = grid,
       _catalog = catalog;

  final CoreModule _core;
  final ProjectsModule _projects;
  final GridModule _grid;
  final CatalogModule _catalog;

  /// Рецепты схем лежат файлами рядом с проектами.
  late final ImageRecipeStore recipes = ImageRecipeStore(_core.fileStore);

  late final ImageRecipeContentCleaner contentCleaner = ImageRecipeContentCleaner(recipes);

  /// Раннер изолята, выбор файла, декодер и маска живут, пока открыт мастер: раннер закрывает сам кубит.
  ImageWizardCubit imageWizardCubit() => ImageWizardCubit(
    source: PickerBookImageSource(),
    // Генератору хватает 2048: поворот и обрезка отзываются быстрее, пик памяти и маска Vision меньше. Книги — 4096.
    processor: const UiImageProcessor(maxSide: wizardImageMaxSide),
    decoder: const UiImageDecoder(),
    runner: IsolateImageToGridRunner(),
    masks: MethodChannelImageMasks(),
    catalog: _catalog.repository,
    settings: _core.settings,
    createPattern: CreatePatternFromImage(_grid.createGridPattern()),
    recipes: recipes,
    replacePattern: ReplacePatternFromImage(
      patterns: _grid.patterns,
      rows: _grid.progress,
      cells: _grid.cellProgress,
      projects: _projects.repository,
    ),
    projects: _projects.repository,
    patterns: _grid.patterns,
    printer: _grid.printer,
    sizeHints: true,
  );

  List<RouteBase> routes() => <RouteBase>[
    GoRoute(
      path: AppRoutes.imageToGrid,
      builder: (_, state) => BlocProvider<ImageWizardCubit>(
        create: (_) {
          final ImageWizardCubit cubit = imageWizardCubit();
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
        child: ImageWizardScreen(fileSharer: _core.fileSharer, rasterizer: PdfrxPdfRasterizer()),
      ),
    ),
  ];
}
