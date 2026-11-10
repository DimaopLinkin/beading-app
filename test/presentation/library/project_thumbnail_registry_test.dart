import 'package:beading/domain/projects/project.dart';
import 'package:beading/presentation/library/project_thumbnail_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'library_cubit_test.dart' show project;

class _KindProvider implements ProjectThumbnailProvider {
  _KindProvider(this.kind, this.label);

  final ContentKind kind;
  final String label;

  @override
  bool supports(Project project) => project.contentKind == kind;

  @override
  Widget build(BuildContext context, Project project) => Text(label);
}

void main() {
  test('берётся первый провайдер, который поддерживает проект', () {
    final ProjectThumbnailRegistry registry = ProjectThumbnailRegistry()
      ..register(_KindProvider(ContentKind.grid, 'сетка'))
      ..register(_KindProvider(ContentKind.image, 'фото'));

    expect((registry.providerFor(project('a', 'x')) as _KindProvider?)?.label, 'фото');
  });

  test('если никто не поддерживает проект, провайдера нет', () {
    final ProjectThumbnailRegistry registry = ProjectThumbnailRegistry()
      ..register(_KindProvider(ContentKind.grid, 'сетка'));

    expect(registry.providerFor(project('a', 'x')), isNull);
  });
}
