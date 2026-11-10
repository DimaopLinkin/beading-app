import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/use_cases/create_pattern_from_image.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_clock.dart';
import '../../../support/fake_grid_pattern.dart';
import '../../../support/fake_project_repository.dart';

void main() {
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;
  late CreatePatternFromImage useCase;

  final GeneratedPattern generated = GeneratedPattern(
    grid: Grid.fromCells(width: 3, height: 2, cells: const <int>[1, 2, 0, 2, 1, 1]),
    palette: const <PaletteEntry>[
      PaletteEntry(rgb: Rgb(255, 0, 0)),
      PaletteEntry(rgb: Rgb(0, 0, 255)),
    ],
  );

  setUp(() {
    projects = FakeProjectRepository();
    patterns = FakeGridPatternRepository();
    final FakeIdGenerator ids = FakeIdGenerator();
    useCase = CreatePatternFromImage(
      CreateGridPattern(
        createProject: CreateProject(repository: projects, ids: ids, clock: FakeClock(DateTime.utc(2026))),
        projects: projects,
        patterns: patterns,
        ids: ids,
      ),
    );
  });

  test('создаёт сеточный проект в технике с сеткой и палитрой', () async {
    final Result<Project> result = await useCase(
      name: 'Розы',
      technique: Technique.peyote,
      metrics: BeadSize.delica11,
      pattern: generated,
    );
    final Project project = result.valueOrNull!;
    expect(project.name, 'Розы');
    expect(project.contentKind, ContentKind.grid);
    expect(project.technique, Technique.peyote);
    expect(project.craft, Craft.beading);
    final GridPattern saved = patterns.byProject[project.id]!;
    expect(saved.grid.cells, generated.grid.cells);
    expect(saved.palette.length, 2);
    expect(saved.geometry, isA<PeyoteGeometry>());
    expect(saved.metrics, BeadSize.delica11);
  });

  test('пустое название — ошибка, проект не создаётся', () async {
    final Result<Project> result = await useCase(
      name: '   ',
      technique: Technique.loom,
      metrics: BeadSize.delica11,
      pattern: generated,
    );
    expect(result, isA<Err<Project>>());
    expect((result as Err<Project>).failure, isA<ValidationFailure>());
    expect(patterns.byProject, isEmpty);
  });

  test('ошибка записи схемы не оставляет проект', () async {
    patterns.failNextSave = const StorageFailure('диск');
    final Result<Project> result = await useCase(
      name: 'Розы',
      technique: Technique.loom,
      metrics: BeadSize.delica11,
      pattern: generated,
    );
    expect(result, isA<Err<Project>>());
  });
}
