import 'package:beading/core/result.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/image_pattern/book_work/record_book_progress.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/change_project_status.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_clock.dart';
import '../../../support/fake_project_repository.dart';

void main() {
  late FakeProjectRepository projects;
  late FakeClock clock;
  late RecordBookProgress record;
  late Project project;

  setUp(() async {
    projects = FakeProjectRepository();
    clock = FakeClock(DateTime.utc(2026, 11, 9, 12));
    record = RecordBookProgress(
      projects: projects,
      changeStatus: ChangeProjectStatus(repository: projects, events: BroadcastAppEvents()),
      touch: TouchProject(repository: projects, clock: clock),
    );
    project = (await CreateProject(repository: projects, ids: FakeIdGenerator(), clock: clock)(
      name: 'Браслет',
    )).valueOrNull!;
  });

  test('первый сдвиг переводит «идею» в «в работе» и обновляет время работы', () async {
    clock.advance(const Duration(hours: 2));

    final Result<Project> result = await record(project.id);

    expect(result.valueOrNull!.status, ProjectStatus.inProgress);
    expect(projects.projects[project.id]!.status, ProjectStatus.inProgress);
    expect(projects.projects[project.id]!.lastWorkedAt, clock.now());
  });

  test('проект уже в работе: статус не меняется, время обновляется', () async {
    await ChangeProjectStatus(repository: projects, events: BroadcastAppEvents())(project.id, ProjectStatus.inProgress);
    clock.advance(const Duration(hours: 1));

    await record(project.id);

    expect(projects.projects[project.id]!.status, ProjectStatus.inProgress);
    expect(projects.projects[project.id]!.lastWorkedAt, clock.now());
  });

  test('готовый проект остаётся готовым', () async {
    await ChangeProjectStatus(repository: projects, events: BroadcastAppEvents())(project.id, ProjectStatus.done);

    await record(project.id);

    expect(projects.projects[project.id]!.status, ProjectStatus.done);
  });

  test('неизвестный проект — ошибка', () async {
    expect((await record('нет')).isFailure, isTrue);
  });
}
