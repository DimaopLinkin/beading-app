import 'package:beading/core/failure.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/presentation/editor/new_grid_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';

void main() {
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;
  late NewGridCubit cubit;

  setUp(() {
    projects = FakeProjectRepository();
    patterns = FakeGridPatternRepository();
    final FakeIdGenerator ids = FakeIdGenerator();
    cubit = NewGridCubit(
      defaultName: 'Новая схема',
      createPattern: CreateGridPattern(
        createProject: CreateProject(repository: projects, ids: ids, clock: FakeClock(DateTime.utc(2026))),
        projects: projects,
        patterns: patterns,
        ids: ids,
      ),
    );
  });

  tearDown(() => cubit.close());

  test('предпросмотр размера в мм: станок 10×40 Delica 11/0', () {
    final size = cubit.state.sizeMm;
    expect(size.width, closeTo(10 * BeadSize.delica11.widthMm, 1e-9));
    expect(size.height, closeTo(40 * BeadSize.delica11.heightMm, 1e-9));
  });

  test('создаёт проект и пустую схему выбранной техники', () async {
    cubit
      ..setTechnique(Technique.peyote)
      ..setWidth(6)
      ..setHeight(20)
      ..setName('  Браслет ')
      ..setBead(BeadSize.delica10);
    await cubit.create();
    final String id = cubit.state.projectId!;
    expect(projects.projects[id]!.name, 'Браслет');
    expect(projects.projects[id]!.technique, Technique.peyote);
    final pattern = patterns.byProject[id]!;
    expect(pattern.geometry, const GridGeometry.peyote());
    expect(pattern.metrics, BeadSize.delica10);
    expect((pattern.grid.width, pattern.grid.height), (6, 20));
  });

  test('без названия — название по умолчанию', () async {
    await cubit.create();
    expect(projects.projects[cubit.state.projectId!]!.name, 'Новая схема');
  });

  test('размер вне допустимого не создаётся', () async {
    cubit.setWidth(0);
    await cubit.create();
    expect(cubit.state.projectId, isNull);
    expect(projects.projects, isEmpty);
    cubit.setWidth(NewGridState.maxSide + 1);
    expect(cubit.state.validSize, isFalse);
  });

  test('ошибка записи: failed, проекта нет', () async {
    patterns.failNextSave = const StorageFailure('диск');
    await cubit.create();
    expect(cubit.state.failed, isTrue);
    expect(cubit.state.projectId, isNull);
    expect(cubit.state.creating, isFalse);
  });
}
