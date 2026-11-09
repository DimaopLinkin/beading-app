import 'dart:async';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_content_cloner.dart';
import 'package:beading/domain/projects/project_filter.dart';
import 'package:beading/domain/projects/use_cases/change_project_status.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/delete_project.dart';
import 'package:beading/domain/projects/use_cases/duplicate_project.dart';
import 'package:beading/domain/projects/use_cases/project_name.dart';
import 'package:beading/domain/projects/use_cases/rename_project.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:beading/domain/projects/use_cases/update_notes.dart';
import 'package:beading/domain/projects/use_cases/watch_projects.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_project_repository.dart';

class _FakeCloner implements ProjectContentCloner {
  _FakeCloner(this.kind, {this.failure});

  final ContentKind kind;
  final Failure? failure;
  final List<String> targets = <String>[];

  @override
  bool supports(ContentKind kind) => kind == this.kind;

  @override
  Future<Result<void>> clone({required Project source, required String targetId}) async {
    targets.add(targetId);
    final Failure? f = failure;
    return f == null ? const Success<void>(null) : Err<void>(f);
  }
}

void main() {
  late FakeProjectRepository repository;
  late FakeIdGenerator ids;
  late FakeClock clock;
  late BroadcastAppEvents events;
  late List<AppEvent> published;

  setUp(() {
    repository = FakeProjectRepository();
    ids = FakeIdGenerator();
    clock = FakeClock(DateTime.utc(2026, 11, 9, 12));
    events = BroadcastAppEvents();
    published = <AppEvent>[];
    final StreamSubscription<AppEvent> sub = events.stream.listen(published.add);
    addTearDown(() async {
      await sub.cancel();
      await events.dispose();
    });
  });

  CreateProject create() => CreateProject(repository: repository, ids: ids, clock: clock);

  Future<Project> created({
    String name = 'Браслет',
    Craft craft = Craft.beading,
    Technique? technique,
    ContentKind contentKind = ContentKind.image,
  }) async => (await create()(
    name: name,
    craft: craft,
    technique: technique,
    contentKind: contentKind,
  )).valueOrNull!;

  group('CreateProject', () {
    test('создаёт идею с бисером и первой техникой по умолчанию', () async {
      final Result<Project> result = await create()(name: '  Браслет  ');
      final Project project = result.valueOrNull!;
      expect(project.id, 'id-1');
      expect(project.name, 'Браслет');
      expect(project.status, ProjectStatus.idea);
      expect(project.craft, Craft.beading);
      expect(project.technique, Technique.loom);
      expect(project.contentKind, ContentKind.image);
      expect(project.notes, '');
      expect(project.coverPath, isNull);
      expect(project.lastWorkedAt, DateTime.utc(2026, 11, 9, 12));
      expect(repository.projects['id-1'], project);
    });

    test('для вышивки берёт технику вышивки по умолчанию', () async {
      final Project project = await created(craft: Craft.crossStitch);
      expect(project.technique, Technique.crossStitch);
    });

    test('техника из чужого ремесла — ValidationFailure, ничего не сохраняется', () async {
      final Result<Project> result = await create()(name: 'X', craft: Craft.crossStitch, technique: Technique.loom);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(repository.projects, isEmpty);
      final Result<Project> reverse = await create()(name: 'X', technique: Technique.tent);
      expect(reverse.failureOrNull, isA<ValidationFailure>());
    });

    test('пустое и слишком длинное название — ValidationFailure', () async {
      expect((await create()(name: '   ')).failureOrNull, isA<ValidationFailure>());
      expect((await create()(name: 'я' * (maxProjectNameLength + 1))).failureOrNull, isA<ValidationFailure>());
      expect((await create()(name: 'я' * maxProjectNameLength)).isSuccess, isTrue);
    });

    test('ошибка хранилища возвращается как Failure', () async {
      repository.failNextWrite = const StorageFailure('диск');
      expect((await create()(name: 'X')).failureOrNull, const StorageFailure('диск'));
    });
  });

  group('RenameProject', () {
    test('меняет название с обрезкой пробелов', () async {
      final Project project = await created();
      final Result<Project> result = await RenameProject(repository)(project.id, '  Колье ');
      expect(result.valueOrNull!.name, 'Колье');
      expect(repository.projects[project.id]!.name, 'Колье');
    });

    test('пустое название и неизвестный проект — Failure', () async {
      final Project project = await created();
      expect((await RenameProject(repository)(project.id, ' ')).failureOrNull, isA<ValidationFailure>());
      expect((await RenameProject(repository)('нет', 'Х')).failureOrNull, isA<NotFoundFailure>());
    });

    test('ошибка записи возвращается', () async {
      final Project project = await created();
      repository.failNextWrite = const StorageFailure('диск');
      expect((await RenameProject(repository)(project.id, 'Х')).failureOrNull, isA<StorageFailure>());
    });
  });

  group('UpdateNotes', () {
    test('заменяет заметки и позволяет очистить', () async {
      final Project project = await created();
      await UpdateNotes(repository)(project.id, 'взять иглу №12');
      expect(repository.projects[project.id]!.notes, 'взять иглу №12');
      await UpdateNotes(repository)(project.id, '');
      expect(repository.projects[project.id]!.notes, '');
    });

    test('неизвестный проект — NotFoundFailure', () async {
      expect((await UpdateNotes(repository)('нет', 'x')).failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('TouchProject', () {
    test('обновляет lastWorkedAt и поднимает проект выше', () async {
      final Project first = await created(name: 'Первый');
      clock.advance(const Duration(hours: 1));
      final Project second = await created(name: 'Второй');
      clock.advance(const Duration(hours: 1));
      final Result<Project> touched = await TouchProject(repository: repository, clock: clock)(first.id);
      expect(touched.valueOrNull!.lastWorkedAt, DateTime.utc(2026, 11, 9, 14));
      final List<Project> list = await WatchProjects(repository)().first;
      expect(list.map((p) => p.id), <String>[first.id, second.id]);
    });

    test('неизвестный проект — NotFoundFailure', () async {
      expect(
        (await TouchProject(repository: repository, clock: clock)('нет')).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });
  });

  group('DeleteProject', () {
    test('удалённый проект не виден в списке и недоступен', () async {
      final Project project = await created();
      expect((await DeleteProject(repository)(project.id)).isSuccess, isTrue);
      expect(await WatchProjects(repository)().first, isEmpty);
      expect((await RenameProject(repository)(project.id, 'Х')).failureOrNull, isA<NotFoundFailure>());
    });

    test('повторное удаление — NotFoundFailure', () async {
      final Project project = await created();
      await DeleteProject(repository)(project.id);
      expect((await DeleteProject(repository)(project.id)).failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('ChangeProjectStatus', () {
    ChangeProjectStatus change() => ChangeProjectStatus(repository: repository, events: events);

    test('переход в «готово» сохраняет статус и публикует ProjectCompleted', () async {
      final Project project = await created();
      final Result<Project> result = await change()(project.id, ProjectStatus.done);
      expect(result.valueOrNull!.status, ProjectStatus.done);
      expect(published, hasLength(1));
      expect((published.single as ProjectCompleted).projectId, project.id);
    });

    test('другие переходы события не публикуют', () async {
      final Project project = await created();
      await change()(project.id, ProjectStatus.inProgress);
      expect(repository.projects[project.id]!.status, ProjectStatus.inProgress);
      expect(published, isEmpty);
    });

    test('повторное «готово» не публикует событие второй раз', () async {
      final Project project = await created();
      await change()(project.id, ProjectStatus.done);
      await change()(project.id, ProjectStatus.done);
      expect(published, hasLength(1));
    });

    test('из «готово» назад и снова в «готово» — событие ещё раз', () async {
      final Project project = await created();
      await change()(project.id, ProjectStatus.done);
      await change()(project.id, ProjectStatus.inProgress);
      await change()(project.id, ProjectStatus.done);
      expect(published, hasLength(2));
    });

    test('ошибка записи: статус не меняется, события нет', () async {
      final Project project = await created();
      repository.failNextWrite = const StorageFailure('диск');
      final Result<Project> result = await change()(project.id, ProjectStatus.done);
      expect(result.failureOrNull, isA<StorageFailure>());
      expect(published, isEmpty);
      expect(repository.projects[project.id]!.status, ProjectStatus.idea);
    });

    test('неизвестный проект — NotFoundFailure', () async {
      expect((await change()('нет', ProjectStatus.done)).failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('WatchProjects', () {
    test('применяет фильтр по ремеслу, технике, статусу и поиску', () async {
      final Project bracelet = await created(name: 'Ёлочка');
      final Project stitch = await created(name: 'Роза', craft: Craft.crossStitch, technique: Technique.tent);
      await ChangeProjectStatus(repository: repository, events: events)(stitch.id, ProjectStatus.done);

      Future<List<String>> names(ProjectFilter filter) async =>
          (await WatchProjects(repository)(filter: filter).first).map((p) => p.name).toList();

      expect(await names(ProjectFilter.all), unorderedEquals(<String>['Ёлочка', 'Роза']));
      expect(await names(const ProjectFilter(craft: Craft.crossStitch)), <String>['Роза']);
      expect(await names(const ProjectFilter(technique: Technique.loom)), <String>['Ёлочка']);
      expect(await names(const ProjectFilter(status: ProjectStatus.done)), <String>['Роза']);
      expect(await names(const ProjectFilter(query: 'елочка')), <String>[bracelet.name]);
    });

    test('поток обновляется при изменениях', () async {
      final Stream<List<Project>> stream = WatchProjects(repository)();
      final Future<void> check = expectLater(
        stream.map((l) => l.map((p) => p.name).toList()),
        emitsInOrder(<Object>[
          <String>[],
          <String>['Новый'],
        ]),
      );
      await pumpEventQueue();
      await created(name: 'Новый');
      await check;
    });
  });

  group('DuplicateProject', () {
    DuplicateProject duplicate(List<ProjectContentCloner> cloners) =>
        DuplicateProject(repository: repository, ids: ids, clock: clock, cloners: cloners);

    test('делает копию с новым id и названием «… (копия)», статус — идея', () async {
      final Project source = await created(contentKind: ContentKind.grid);
      await UpdateNotes(repository)(source.id, 'заметка');
      await ChangeProjectStatus(repository: repository, events: events)(source.id, ProjectStatus.done);
      clock.advance(const Duration(days: 1));

      final Project copy = (await duplicate(<ProjectContentCloner>[])(source.id)).valueOrNull!;

      expect(copy.id, isNot(source.id));
      expect(copy.name, 'Браслет (копия)');
      expect(copy.status, ProjectStatus.idea);
      expect(copy.craft, source.craft);
      expect(copy.technique, source.technique);
      expect(copy.contentKind, ContentKind.grid);
      expect(copy.notes, 'заметка');
      expect(copy.coverPath, isNull);
      expect(copy.lastWorkedAt, DateTime.utc(2026, 11, 10, 12));
      expect(repository.projects[source.id]!.status, ProjectStatus.done);
    });

    test('вызывает только клонеры своего вида содержимого', () async {
      final Project source = await created(contentKind: ContentKind.grid);
      final _FakeCloner grid = _FakeCloner(ContentKind.grid);
      final _FakeCloner image = _FakeCloner(ContentKind.image);
      final Project copy = (await duplicate(<ProjectContentCloner>[grid, image])(source.id)).valueOrNull!;
      expect(grid.targets, <String>[copy.id]);
      expect(image.targets, isEmpty);
    });

    test('сбой клонера удаляет копию и возвращает ошибку', () async {
      final Project source = await created();
      final _FakeCloner broken = _FakeCloner(ContentKind.image, failure: const StorageFailure('нет места'));
      final Result<Project> result = await duplicate(<ProjectContentCloner>[broken])(source.id);
      expect(result.failureOrNull, const StorageFailure('нет места'));
      expect((await WatchProjects(repository)().first).map((p) => p.id), <String>[source.id]);
    });

    test('название не превышает максимум', () async {
      final Project source = await created(name: 'я' * maxProjectNameLength);
      final Project copy = (await duplicate(<ProjectContentCloner>[])(source.id)).valueOrNull!;
      expect(copy.name.length, maxProjectNameLength);
      expect(copy.name, endsWith(DuplicateProject.copySuffix));
    });

    test('неизвестный проект и ошибка записи — Failure', () async {
      expect((await duplicate(<ProjectContentCloner>[])('нет')).failureOrNull, isA<NotFoundFailure>());
      final Project source = await created();
      repository.failNextWrite = const StorageFailure('диск');
      expect((await duplicate(<ProjectContentCloner>[])(source.id)).failureOrNull, isA<StorageFailure>());
    });
  });
}
