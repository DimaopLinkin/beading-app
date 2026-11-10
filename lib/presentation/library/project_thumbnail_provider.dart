import 'package:beading/domain/projects/project.dart';
import 'package:flutter/cupertino.dart';

/// Рисует превью проекта на карточке. Реализации подключают фичи, у которых есть что показать
/// (страница книги, сетка); для остальных библиотека рисует значок ремесла.
abstract interface class ProjectThumbnailProvider {
  bool supports(Project project);

  /// Квадратное превью; размер задаёт карточка.
  Widget build(BuildContext context, Project project);
}

class ProjectThumbnailRegistry {
  final List<ProjectThumbnailProvider> _providers = <ProjectThumbnailProvider>[];

  void register(ProjectThumbnailProvider provider) => _providers.add(provider);

  ProjectThumbnailProvider? providerFor(Project project) {
    for (final ProjectThumbnailProvider provider in _providers) {
      if (provider.supports(project)) {
        return provider;
      }
    }
    return null;
  }
}
