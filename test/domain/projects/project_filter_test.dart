import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_filter.dart';
import 'package:flutter_test/flutter_test.dart';

Project _project({
  String name = 'Браслет',
  Craft craft = Craft.beading,
  Technique technique = Technique.loom,
  ProjectStatus status = ProjectStatus.idea,
}) => Project(
  id: 'p',
  name: name,
  status: status,
  craft: craft,
  technique: technique,
  contentKind: ContentKind.image,
  notes: '',
  coverPath: null,
  lastWorkedAt: DateTime.utc(2026),
);

void main() {
  test('пустой фильтр пропускает всё', () {
    expect(ProjectFilter.all.matches(_project()), isTrue);
  });

  test('фильтр по ремеслу, технике и статусу', () {
    final Project stitch = _project(craft: Craft.crossStitch, technique: Technique.tent, status: ProjectStatus.done);
    expect(const ProjectFilter(craft: Craft.beading).matches(stitch), isFalse);
    expect(const ProjectFilter(craft: Craft.crossStitch).matches(stitch), isTrue);
    expect(const ProjectFilter(technique: Technique.tent).matches(stitch), isTrue);
    expect(const ProjectFilter(technique: Technique.loom).matches(stitch), isFalse);
    expect(const ProjectFilter(status: ProjectStatus.done).matches(stitch), isTrue);
    expect(const ProjectFilter(status: ProjectStatus.idea).matches(stitch), isFalse);
  });

  test('поиск не различает регистр и «ё/е»', () {
    final Project project = _project(name: 'Ёлочка из бисера');
    expect(const ProjectFilter(query: 'елочка').matches(project), isTrue);
    expect(const ProjectFilter(query: 'ЁЛОЧ').matches(project), isTrue);
    expect(const ProjectFilter(query: '  бисера ').matches(project), isTrue);
    expect(const ProjectFilter(query: 'ёж').matches(project), isFalse);
    expect(const ProjectFilter(query: 'Бисер').matches(_project(name: 'бИсЕр')), isTrue);
    expect(const ProjectFilter(query: 'ёлка').matches(_project(name: 'ёлка')), isTrue);
  });

  test('условия складываются по И', () {
    final Project project = _project();
    expect(const ProjectFilter(craft: Craft.beading, query: 'брас').matches(project), isTrue);
    expect(const ProjectFilter(craft: Craft.beading, query: 'серьги').matches(project), isFalse);
  });
}
