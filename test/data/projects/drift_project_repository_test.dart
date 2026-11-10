import 'package:beading/core/failure.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/projects/drift_project_repository.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_filter.dart';
import 'package:beading/domain/projects/use_cases/watch_projects.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_project_repository.dart';
import '../../support/in_memory_database.dart';

Project _project(String id, {String name = 'Браслет', DateTime? worked, ProjectStatus status = ProjectStatus.idea}) =>
    Project(
      id: id,
      name: name,
      status: status,
      craft: Craft.beading,
      technique: Technique.peyote,
      contentKind: ContentKind.grid,
      notes: 'заметка',
      coverPath: 'covers/$id.jpg',
      lastWorkedAt: worked ?? DateTime.utc(2026, 11, 9),
    );

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late DriftProjectRepository repository;

  setUp(() {
    db = createInMemoryDatabase();
    clock = FakeClock(DateTime.utc(2026, 11, 9, 10));
    repository = DriftProjectRepository(
      dao: db.projectsDao,
      deviceIds: DriftDeviceIdProvider(dao: db.settingsDao, ids: FakeIdGenerator(), clock: clock),
      clock: clock,
    );
  });

  test('сохранённый проект читается без потерь', () async {
    final Project project = _project('a');
    expect((await repository.save(project)).isSuccess, isTrue);
    expect((await repository.get('a')).valueOrNull, project);
  });

  test('служебные колонки: created_at, updated_at, device_id', () async {
    await repository.save(_project('a'));
    clock.advance(const Duration(minutes: 5));
    await repository.save(_project('a', name: 'Колье'));

    final ProjectRow row = (await db.projectsDao.find('a'))!;
    expect(row.createdAt, DateTime.utc(2026, 11, 9, 10).millisecondsSinceEpoch);
    expect(row.updatedAt, DateTime.utc(2026, 11, 9, 10, 5).millisecondsSinceEpoch);
    expect(row.deviceId, isNotEmpty);
    expect(row.name, 'Колье');
  });

  test('неизвестный проект — NotFoundFailure', () async {
    expect((await repository.get('нет')).failureOrNull, isA<NotFoundFailure>());
  });

  test('удаление ставит надгробие: проект скрыт, строка остаётся', () async {
    await repository.save(_project('a'));
    clock.advance(const Duration(minutes: 1));
    expect((await repository.delete('a')).isSuccess, isTrue);

    expect((await repository.get('a')).failureOrNull, isA<NotFoundFailure>());
    expect(await repository.watchAll().first, isEmpty);
    final ProjectRow row = (await db.projectsDao.find('a'))!;
    expect(row.deletedAt, DateTime.utc(2026, 11, 9, 10, 1).millisecondsSinceEpoch);
  });

  test('удалить отсутствующий или уже удалённый — NotFoundFailure; сохранить удалённый — тоже', () async {
    expect((await repository.delete('нет')).failureOrNull, isA<NotFoundFailure>());
    await repository.save(_project('a'));
    await repository.delete('a');
    expect((await repository.delete('a')).failureOrNull, isA<NotFoundFailure>());
    expect((await repository.save(_project('a'))).failureOrNull, isA<NotFoundFailure>());
  });

  test('список отсортирован по lastWorkedAt, при равенстве новый id выше', () async {
    await repository.save(_project('a', worked: DateTime.utc(2026, 1, 5)));
    await repository.save(_project('b', worked: DateTime.utc(2026, 3, 5)));
    await repository.save(_project('c', worked: DateTime.utc(2026, 3, 5)));
    await repository.save(_project('d', worked: DateTime.utc(2026, 2, 5)));
    final List<Project> list = await repository.watchAll().first;
    expect(list.map((p) => p.id), <String>['c', 'b', 'd', 'a']);
  });

  test('поток обновляется при записи и удалении', () async {
    final Future<void> check = expectLater(
      repository.watchAll().map((l) => l.map((p) => p.id).toList()),
      emitsInOrder(<Object>[
        <String>[],
        <String>['a'],
        <String>[],
      ]),
    );
    await pumpEventQueue();
    await repository.save(_project('a'));
    await pumpEventQueue();
    await repository.delete('a');
    await check;
  });

  test('WatchProjects: поиск по «ё/е» и без регистра на настоящей базе, фильтр по ремеслу', () async {
    await repository.save(_project('a', name: 'Ёлочка'));
    await repository.save(
      Project(
        id: 'b',
        name: 'Роза',
        status: ProjectStatus.inProgress,
        craft: Craft.crossStitch,
        technique: Technique.tent,
        contentKind: ContentKind.image,
        notes: '',
        coverPath: null,
        lastWorkedAt: DateTime.utc(2026),
      ),
    );
    final WatchProjects watch = WatchProjects(repository);
    expect((await watch(filter: const ProjectFilter(query: 'ЕЛОЧКА')).first).map((p) => p.id), <String>['a']);
    expect((await watch(filter: const ProjectFilter(craft: Craft.crossStitch)).first).map((p) => p.id), <String>['b']);
  });

  test('неизвестные значения в строке заменяются безопасными, список не падает', () async {
    await db.projectsDao.insertRow(
      ProjectsCompanion.insert(
        id: 'x',
        name: 'Из будущего',
        craft: const Value<String>('knitting'),
        status: const Value<String>('archived'),
        technique: 'crochet',
        contentKind: 'video',
        lastWorkedAt: 0,
        createdAt: 0,
        updatedAt: 0,
        deviceId: 'd',
      ),
    );
    final Project project = (await repository.watchAll().first).single;
    expect(project.craft, Craft.beading);
    expect(project.status, ProjectStatus.idea);
    expect(project.technique, Technique.loom);
    expect(project.contentKind, ContentKind.image);
  });

  test('техника, не подходящая ремеслу в строке, заменяется на технику по умолчанию', () async {
    await db.projectsDao.insertRow(
      ProjectsCompanion.insert(
        id: 'y',
        name: 'Смесь',
        craft: const Value<String>('crossStitch'),
        technique: 'loom',
        contentKind: 'image',
        lastWorkedAt: 0,
        createdAt: 0,
        updatedAt: 0,
        deviceId: 'd',
      ),
    );
    expect((await repository.get('y')).valueOrNull!.technique, Technique.crossStitch);
  });

  test('ошибка хранилища превращается в StorageFailure', () async {
    await db.customStatement('DROP TABLE projects');
    expect((await repository.save(_project('a'))).failureOrNull, isA<StorageFailure>());
  });
}
