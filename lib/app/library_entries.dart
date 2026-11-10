import 'package:beading/app/router.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/presentation/library/new_project_entry.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:go_router/go_router.dart';

/// Пункты листа «Новый проект», которые уже есть в приложении. Новые фичи (T17, T23, T25) добавляют свои сюда.
void registerLibraryEntries(NewProjectRegistry registry) {
  // Экран импорта сам спрашивает ремесло, поэтому пункт показываем в обоих.
  for (final Craft craft in Craft.values) {
    registry.register(
      NewProjectEntry(
        id: 'import-book-${craft.name}',
        craft: craft,
        order: 10,
        title: (l10n) => l10n.libraryImportBook,
        icon: AppIcons.add,
        onSelected: (context) async {
          // Новая схема сразу открывается для работы.
          final String? projectId = await context.push<String>(AppRoutes.importBook);
          if (projectId != null && context.mounted) {
            await context.push<void>(AppRoutes.bookWork(projectId));
          }
        },
      ),
    );
  }

  // Редактор бисерных схем (T17); вышивку редактирует T40.
  registry.register(
    NewProjectEntry(
      id: 'draw-grid-beading',
      craft: Craft.beading,
      order: 20,
      title: (l10n) => l10n.libraryDrawPattern,
      icon: AppIcons.brush,
      onSelected: (context) async {
        final String? projectId = await context.push<String>(AppRoutes.newGrid);
        if (projectId != null && context.mounted) {
          await context.push<void>(AppRoutes.editor(projectId));
        }
      },
    ),
  );

  // Схема из фото: бисер. Для вышивки свой мастер сделает T46.
  registry.register(
    NewProjectEntry(
      id: 'image-to-grid-${Craft.beading.name}',
      craft: Craft.beading,
      order: 30,
      title: (l10n) => l10n.libraryImageToGrid,
      icon: AppIcons.photo,
      onSelected: (context) async {
        // Готовую схему сразу открываем в редакторе: подправить лишнее и начать работу.
        final String? projectId = await context.push<String>(AppRoutes.imageToGrid);
        if (projectId != null && context.mounted) {
          await context.push<void>(AppRoutes.editor(projectId));
        }
      },
    ),
  );

  // Узор по готовому шаблону: бисер; после сохранения проект открывается в редакторе.
  registry.register(
    NewProjectEntry(
      id: 'pattern-template',
      craft: Craft.beading,
      order: 40,
      title: (l10n) => l10n.templateEntryTitle,
      icon: AppIcons.template,
      onSelected: (context) async {
        final String? projectId = await context.push<String>(AppRoutes.patternTemplate);
        if (projectId != null && context.mounted) {
          await context.push<void>(AppRoutes.editor(projectId));
        }
      },
    ),
  );
}
