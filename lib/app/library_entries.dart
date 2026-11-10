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
}
