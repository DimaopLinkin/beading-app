import 'package:beading/core/failure.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/cell_metrics_codec.dart';
import 'package:beading/domain/materials/use_cases/load_project_materials.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/presentation/materials/materials_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';

Project gridProject({String id = 'proj-1', String name = 'Браслет'}) => Project(
  id: id,
  name: name,
  status: ProjectStatus.idea,
  craft: Craft.beading,
  technique: Technique.defaultFor(Craft.beading),
  contentKind: ContentKind.grid,
  notes: '',
  coverPath: null,
  lastWorkedAt: DateTime.utc(2026),
);

void main() {
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;

  setUp(() {
    projects = FakeProjectRepository()..projects['proj-1'] = gridProject();
    patterns = FakeGridPatternRepository()..byProject['proj-1'] = sampleGridPattern();
  });

  MaterialsCubit make([String id = 'proj-1']) {
    final MaterialsCubit cubit = MaterialsCubit(
      projectId: id,
      loadMaterials: LoadProjectMaterials(patterns),
      projects: projects,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('load: имя проекта и расход по схеме, количество без запаса', () async {
    final MaterialsCubit cubit = make();

    await cubit.load();

    expect(cubit.state.status, MaterialsStatus.ready);
    expect(cubit.state.projectName, 'Браслет');
    expect(cubit.state.estimate!.totalPieces, 9);
    expect(cubit.state.withReserve, isFalse);
    expect(cubit.state.isEmpty, isFalse);
  });

  test('setWithReserve переключает показ запаса и не пересчитывает расход', () async {
    final MaterialsCubit cubit = make();
    await cubit.load();
    final estimate = cubit.state.estimate;

    cubit.setWithReserve(value: true);

    expect(cubit.state.withReserve, isTrue);
    expect(cubit.state.estimate, same(estimate));
  });

  test('схема без бусин — пустой расход', () async {
    patterns.byProject['proj-1'] = sampleGridPattern().copyWith(
      grid: Grid.empty(width: 4, height: 3),
    );
    final MaterialsCubit cubit = make();

    await cubit.load();

    expect(cubit.state.status, MaterialsStatus.ready);
    expect(cubit.state.isEmpty, isTrue);
  });

  test('проекта нет — failure с NotFoundFailure', () async {
    final MaterialsCubit cubit = make('нет');

    await cubit.load();

    expect(cubit.state.status, MaterialsStatus.failure);
    expect(cubit.state.failure, isA<NotFoundFailure>());
  });

  test('у проекта нет схемы — failure с именем проекта', () async {
    patterns.byProject.clear();
    final MaterialsCubit cubit = make();

    await cubit.load();

    expect(cubit.state.status, MaterialsStatus.failure);
    expect(cubit.state.failure, isA<NotFoundFailure>());
    expect(cubit.state.projectName, 'Браслет');
  });

  test('произвольный размер ячейки — failure ValidationFailure', () async {
    patterns.byProject['proj-1'] = sampleGridPattern().copyWith(
      metrics: const CustomCellMetrics(widthMm: 2, heightMm: 3),
    );
    final MaterialsCubit cubit = make();

    await cubit.load();

    expect(cubit.state.failure, isA<ValidationFailure>());
  });

  test('повторный load после починки возвращает данные', () async {
    patterns.byProject.clear();
    final MaterialsCubit cubit = make();
    await cubit.load();
    patterns.byProject['proj-1'] = sampleGridPattern();

    await cubit.load();

    expect(cubit.state.status, MaterialsStatus.ready);
  });
}
