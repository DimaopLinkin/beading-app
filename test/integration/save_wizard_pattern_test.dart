import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/grid_pattern/drift_grid_pattern_repository.dart';
import 'package:beading/data/projects/drift_project_repository.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/use_cases/create_pattern_from_image.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_clock.dart';
import '../support/fake_project_repository.dart';
import '../support/in_memory_database.dart';

void main() {
  test('схема из картинки сохраняется в настоящую базу (с триггерами синхронизации)', () async {
    final AppDatabase db = createInMemoryDatabase();
    addTearDown(db.close);
    final FakeClock clock = FakeClock(DateTime.utc(2026, 11, 12));
    final DriftDeviceIdProvider devices = DriftDeviceIdProvider(
      dao: db.settingsDao,
      ids: FakeIdGenerator(),
      clock: clock,
    );
    final UuidV7IdGenerator ids = UuidV7IdGenerator();
    final DriftProjectRepository projects = DriftProjectRepository(
      dao: db.projectsDao,
      deviceIds: devices,
      clock: clock,
    );
    final DriftGridPatternRepository patterns = DriftGridPatternRepository(
      dao: db.gridPatternsDao,
      deviceIds: devices,
      clock: clock,
      ids: ids,
    );
    final CreatePatternFromImage useCase = CreatePatternFromImage(
      CreateGridPattern(
        createProject: CreateProject(repository: projects, ids: ids, clock: clock),
        projects: projects,
        patterns: patterns,
        ids: ids,
      ),
    );
    const int w = 600;
    const int h = 400;
    final GeneratedPattern generated = GeneratedPattern(
      grid: Grid.fromCells(width: w, height: h, cells: List<int>.generate(w * h, (i) => 1 + i % 3)),
      palette: const <PaletteEntry>[
        PaletteEntry(rgb: Rgb(255, 0, 0)),
        PaletteEntry(rgb: Rgb(0, 255, 0)),
        PaletteEntry(rgb: Rgb(0, 0, 255)),
      ],
    );

    final Result<Project> result = await useCase(
      name: 'Кот',
      technique: Technique.crossStitch,
      metrics: Fabric.standard,
      pattern: generated,
    );

    expect(result, isA<Success<Project>>(), reason: '$result');
  });
}
