import 'package:beading/presentation/book_work/book_work_screen.dart';
import 'package:beading/presentation/catalog/catalog_screen.dart';
import 'package:beading/presentation/editor/editor_screen.dart';
import 'package:beading/presentation/editor/new_grid_screen.dart';
import 'package:beading/presentation/editor/new_stitch_screen.dart';
import 'package:beading/presentation/floss/floss_screen.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_screen.dart';
import 'package:beading/presentation/import_book/import_book_screen.dart';
import 'package:beading/presentation/materials/materials_screen.dart';
import 'package:beading/presentation/pattern_template/pattern_template_screen.dart';
import 'package:beading/presentation/stitching/stitch_screen.dart';
import 'package:beading/presentation/weaving/weave_screen.dart';

abstract final class AppRoutes {
  static const String library = '/';
  static const String settings = '/settings';
  static const String about = '/settings/about';
  static const String hidden = '/settings/about/hidden';
  static const String glassCheck = '/settings/glass-check';

  /// «Схема из книги». Закрывается с id созданного проекта.
  static const String importBook = ImportBookScreen.routePath;

  /// «Узор по шаблону». Закрывается с id созданного проекта.
  static const String patternTemplate = PatternTemplateScreen.routePath;

  /// Плетение по своей схеме (T19).
  static String weave(String projectId) => WeaveScreen.locationFor(projectId);

  static String stitch(String projectId) => StitchScreen.locationFor(projectId);

  /// «Схема из картинки» (T25). Закрывается с id созданного проекта.
  static const String imageToGrid = ImageWizardScreen.routePath;

  /// Каталог цветов бисера (T20).
  static const String catalog = CatalogScreen.routePath;

  /// Каталог ниток мулине и запас «есть у меня».
  static const String flossCatalog = '/catalog/floss';

  /// Материалы проекта: расход бисера по цветам схемы (T20).
  static String materials(String projectId) => MaterialsScreen.locationFor(projectId);
  static String floss(String projectId) => FlossScreen.locationFor(projectId);

  /// Работа по схеме из книги (T07): линейка, зум, страницы, заметки. T05 откроет её из карточки проекта.
  /// Лист создания схемы (T17). Закрывается с id созданного проекта.
  static const String newGrid = NewGridScreen.routePath;
  static const String newStitch = NewStitchScreen.routePath;

  /// Редактор сеточной схемы (T17).
  static String editor(String projectId) => EditorScreen.locationFor(projectId);

  static String bookWork(String projectId) => BookWorkScreen.locationFor(projectId);
}
