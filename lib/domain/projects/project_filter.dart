import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:equatable/equatable.dart';

/// Условия отбора проектов в библиотеке. Незаданное условие не ограничивает.
class ProjectFilter extends Equatable {
  const ProjectFilter({this.craft, this.technique, this.status, this.query = ''});

  static const ProjectFilter all = ProjectFilter();

  final Craft? craft;
  final Technique? technique;
  final ProjectStatus? status;

  /// Часть названия; регистр и различие «ё/е» не важны.
  final String query;

  bool matches(Project project) {
    if (craft != null && project.craft != craft) {
      return false;
    }
    if (technique != null && project.technique != technique) {
      return false;
    }
    if (status != null && project.status != status) {
      return false;
    }
    final String needle = normalizeSearchText(query);
    return needle.isEmpty || normalizeSearchText(project.name).contains(needle);
  }

  /// Приводит текст к виду для поиска: без краёв-пробелов, в нижнем регистре, «ё» → «е».
  static String normalizeSearchText(String text) => text.trim().toLowerCase().replaceAll('ё', 'е');

  @override
  List<Object?> get props => <Object?>[craft, technique, status, query];
}
