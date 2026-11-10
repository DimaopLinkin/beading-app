import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/cell_metrics_codec.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_content.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/grid_pattern/use_cases/grid_progress_commands.dart';
import 'package:beading/domain/grid_pattern/use_cases/save_grid_pattern.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/delete_project.dart';
import 'package:beading/domain/projects/use_cases/duplicate_project.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';

void main() {
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;
  late FakeGridProgressStore progress;
  late FakeIdGenerator ids;
  late FakeClock clock;

  setUp(() {
    projects = FakeProjectRepository();
    patterns = FakeGridPatternRepository();
    progress = FakeGridProgressStore();
    ids = FakeIdGenerator();
    clock = FakeClock(DateTime.utc(2026, 11, 10, 12));
  });

  CreateGridPattern createUseCase() => CreateGridPattern(
    createProject: CreateProject(repository: projects, ids: ids, clock: clock),
    projects: projects,
    patterns: patterns,
    ids: ids,
  );

  group('CreateGridPattern', () {
    test('создаёт проект contentKind=grid и пустую схему нужного размера', () async {
      final Result<CreatedGridPattern> result = await createUseCase()(
        name: 'Браслет',
        metrics: BeadSize.delica11,
        width: 30,
        height: 400,
        technique: Technique.loom,
      );

      final CreatedGridPattern created = result.valueOrNull!;
      expect(created.project.contentKind, ContentKind.grid);
      expect(created.project.technique, Technique.loom);
      expect(created.pattern.projectId, created.project.id);
      expect(created.pattern.grid, Grid.empty(width: 30, height: 400));
      expect(created.pattern.palette.length, 0);
      expect(patterns.byProject[created.project.id], created.pattern);
      expect(projects.projects[created.project.id], created.project);
    });

    test('принимает готовую сетку, палитру, геометрию и ремесло (вышивка)', () async {
      final GridPattern sample = sampleGridPattern();

      final CreatedGridPattern created = (await createUseCase()(
        name: 'Крестик',
        craft: Craft.crossStitch,
        metrics: const CustomCellMetrics(widthMm: 0.7, heightMm: 0.7),
        width: 4,
        height: 3,
        grid: sample.grid,
        palette: sample.palette,
      )).valueOrNull!;

      expect(created.project.craft, Craft.crossStitch);
      expect(created.pattern.grid, sample.grid);
      expect(created.pattern.palette, sample.palette);
    });

    test('если схему не записать, проекта не остаётся', () async {
      patterns.failNextSave = const StorageFailure('диск');

      final Result<CreatedGridPattern> result = await createUseCase()(
        name: 'Браслет',
        metrics: BeadSize.delica11,
        width: 5,
        height: 5,
      );

      expect(result.failureOrNull, const StorageFailure('диск'));
      expect(projects.deleted, projects.projects.keys.toSet());
    });

    test('размер ячейки, который нельзя записать, отклоняется до создания проекта', () async {
      final Result<CreatedGridPattern> result = await createUseCase()(
        name: 'Х',
        metrics: const _UnstorableMetrics(),
        width: 5,
        height: 5,
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(projects.projects, isEmpty);
    });

    test('пустое имя и техника чужого ремесла отклоняются до записи схемы', () async {
      expect(
        (await createUseCase()(name: ' ', metrics: BeadSize.delica11, width: 5, height: 5)).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        (await createUseCase()(
          name: 'Х',
          metrics: BeadSize.delica11,
          width: 5,
          height: 5,
          technique: Technique.crossStitch,
        )).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(patterns.byProject, isEmpty);
    });

    test('недопустимый размер сетки и цвет вне палитры — ValidationFailure, проект не создаётся', () async {
      expect(
        (await createUseCase()(name: 'Х', metrics: BeadSize.delica11, width: 0, height: 5)).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        (await createUseCase()(
          name: 'Х',
          metrics: BeadSize.delica11,
          width: 1,
          height: 1,
          grid: Grid.fromCells(width: 1, height: 1, cells: const <int>[3]),
          palette: samplePalette(),
        )).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(projects.projects, isEmpty);
    });
  });

  group('SaveGridPattern', () {
    test('сохраняет согласованную схему', () async {
      final GridPattern pattern = sampleGridPattern();

      expect((await SaveGridPattern(patterns)(pattern)).isSuccess, isTrue);
      expect(patterns.byProject['proj-1'], pattern);
    });

    test('цвет сетки вне палитры не пускает в хранилище', () async {
      final GridPattern broken = sampleGridPattern().copyWith(palette: PaletteSnapshot.empty());

      expect((await SaveGridPattern(patterns)(broken)).failureOrNull, isA<ValidationFailure>());
      expect(patterns.byProject, isEmpty);
    });

    test('размер ячейки, который нельзя записать, не пускает в хранилище', () async {
      final GridPattern broken = sampleGridPattern().copyWith(metrics: const _UnstorableMetrics());

      expect((await SaveGridPattern(patterns)(broken)).failureOrNull, isA<ValidationFailure>());
      expect(patterns.byProject, isEmpty);
    });

    test('ошибка хранилища возвращается как есть', () async {
      patterns.failNextSave = const StorageFailure('диск');

      expect((await SaveGridPattern(patterns)(sampleGridPattern())).failureOrNull, const StorageFailure('диск'));
    });
  });

  group('отметки рядов', () {
    setUp(() => patterns.byProject['proj-1'] = sampleGridPattern());

    test('MarkRow отмечает ряд схемы проекта, UnmarkRow снимает', () async {
      final MarkRow mark = MarkRow(patterns: patterns, progress: progress);
      final UnmarkRow unmark = UnmarkRow(patterns: patterns, progress: progress);

      expect((await mark(projectId: 'proj-1', row: 2)).isSuccess, isTrue);
      expect(progress.rows, <int>{2});
      expect((await unmark(projectId: 'proj-1', row: 2)).isSuccess, isTrue);
      expect(progress.rows, isEmpty);
      expect(progress.calls, <String>['mark pat-1 2', 'unmark pat-1 2']);
    });

    test('ряд вне схемы — ValidationFailure, прогресс не меняется', () async {
      final MarkRow mark = MarkRow(patterns: patterns, progress: progress);
      final UnmarkRow unmark = UnmarkRow(patterns: patterns, progress: progress);

      expect((await mark(projectId: 'proj-1', row: 3)).failureOrNull, isA<ValidationFailure>());
      expect((await mark(projectId: 'proj-1', row: -1)).failureOrNull, isA<ValidationFailure>());
      expect((await unmark(projectId: 'proj-1', row: 99)).failureOrNull, isA<ValidationFailure>());
      expect(progress.calls, isEmpty);
    });

    test('у проекта без схемы — NotFoundFailure', () async {
      expect(
        (await MarkRow(patterns: patterns, progress: progress)(projectId: 'нет', row: 0)).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });

    test('SetCurrentBead запоминает ряд и бусину, бусина может быть пустой', () async {
      final SetCurrentBead setCurrent = SetCurrentBead(patterns: patterns, progress: progress);

      expect((await setCurrent(projectId: 'proj-1', row: 1, bead: 3)).isSuccess, isTrue);
      expect((progress.currentRow, progress.currentBead), (1, 3));
      expect((await setCurrent(projectId: 'proj-1', row: 2)).isSuccess, isTrue);
      expect((progress.currentRow, progress.currentBead), (2, null));
    });

    test('SetCurrentBead отклоняет ряд и бусину вне схемы 4×3', () async {
      final SetCurrentBead setCurrent = SetCurrentBead(patterns: patterns, progress: progress);

      expect((await setCurrent(projectId: 'proj-1', row: 3)).failureOrNull, isA<ValidationFailure>());
      expect((await setCurrent(projectId: 'proj-1', row: 0, bead: 4)).failureOrNull, isA<ValidationFailure>());
      expect((await setCurrent(projectId: 'proj-1', row: 0, bead: -1)).failureOrNull, isA<ValidationFailure>());
      expect(progress.calls, isEmpty);
    });
  });

  group('GridProgress', () {
    test('равенство не зависит от порядка отметок и защищает множество от правок', () {
      final Set<int> source = <int>{3, 1};
      final GridProgress a = GridProgress(completedRows: source, currentRow: 1);
      source.add(9);

      expect(a, GridProgress(completedRows: const <int>{1, 3}, currentRow: 1));
      expect(a.completedRows, <int>{1, 3});
      expect(() => a.completedRows.add(5), throwsUnsupportedError);
      expect(const GridProgress.empty(), GridProgress());
    });
  });

  group('дублирование и удаление', () {
    test('клонер копирует сетку и палитру под новым id в новый проект, слои сохраняются', () async {
      final GridPattern original = sampleGridPattern().copyWith(
        layers: GridLayersBlob(codecVersion: 1, bytes: Uint8List.fromList(<int>[1, 2, 3])),
      );
      patterns.byProject['proj-1'] = original;
      final GridPatternContentCloner cloner = GridPatternContentCloner(patterns: patterns, ids: ids);

      final Result<void> result = await cloner.clone(
        source: _project('proj-1', ContentKind.grid),
        targetId: 'proj-2',
      );

      expect(result.isSuccess, isTrue);
      final GridPattern copy = patterns.byProject['proj-2']!;
      expect(copy.id, isNot(original.id));
      expect(copy.projectId, 'proj-2');
      expect(copy.grid, original.grid);
      expect(copy.palette, original.palette);
      expect(copy.layers, original.layers);
      expect(patterns.byProject['proj-1'], original);
    });

    test('клонер поддерживает только grid, у проекта без схемы копировать нечего', () async {
      final GridPatternContentCloner cloner = GridPatternContentCloner(patterns: patterns, ids: ids);

      expect(cloner.supports(ContentKind.grid), isTrue);
      expect(cloner.supports(ContentKind.image), isFalse);
      expect((await cloner.clone(source: _project('p', ContentKind.grid), targetId: 'q')).isSuccess, isTrue);
      expect(patterns.byProject, isEmpty);
    });

    test('ошибка записи копии возвращается', () async {
      patterns.byProject['proj-1'] = sampleGridPattern();
      patterns.failNextSave = const StorageFailure('диск');
      final GridPatternContentCloner cloner = GridPatternContentCloner(patterns: patterns, ids: ids);

      expect(
        (await cloner.clone(source: _project('proj-1', ContentKind.grid), targetId: 'proj-2')).failureOrNull,
        const StorageFailure('диск'),
      );
    });

    test('DuplicateProject с клонером сеток создаёт независимую копию', () async {
      final CreatedGridPattern created = (await createUseCase()(
        name: 'Браслет',
        metrics: BeadSize.delica11,
        width: 4,
        height: 3,
      )).valueOrNull!;
      final DuplicateProject duplicate = DuplicateProject(
        repository: projects,
        ids: ids,
        clock: clock,
        cloners: <GridPatternContentCloner>[GridPatternContentCloner(patterns: patterns, ids: ids)],
      );

      final Project copy = (await duplicate(created.project.id)).valueOrNull!;

      expect(copy.contentKind, ContentKind.grid);
      expect(patterns.byProject[copy.id]!.grid, created.pattern.grid);
      expect(patterns.byProject[copy.id]!.id, isNot(created.pattern.id));
    });

    test('DeleteProject с чистильщиком удаляет сетку проекта', () async {
      final CreatedGridPattern created = (await createUseCase()(
        name: 'Браслет',
        metrics: BeadSize.delica11,
        width: 4,
        height: 3,
      )).valueOrNull!;
      final DeleteProject delete = DeleteProject(
        projects,
        cleaners: <GridPatternContentCleaner>[GridPatternContentCleaner(patterns)],
      );

      expect((await delete(created.project.id)).isSuccess, isTrue);
      expect(patterns.deletedProjects, <String>[created.project.id]);
      expect(patterns.byProject, isEmpty);
    });
  });
}

Project _project(String id, ContentKind kind) => Project(
  id: id,
  name: 'П',
  status: ProjectStatus.idea,
  craft: Craft.beading,
  technique: Technique.loom,
  contentKind: kind,
  notes: '',
  coverPath: null,
  lastWorkedAt: DateTime.utc(2026),
);

class _UnstorableMetrics implements CellMetrics {
  const _UnstorableMetrics();

  @override
  double get widthMm => 1;

  @override
  double get heightMm => 1;
}
