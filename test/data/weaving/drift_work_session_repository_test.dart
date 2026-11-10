import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/work_sessions_dao.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/data/weaving/drift_work_session_repository.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/weaving/work_session.dart';
import 'package:beading/domain/weaving/work_session_content_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_project_repository.dart';
import '../../support/in_memory_database.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late DriftWorkSessionRepository repository;

  Future<void> insertProject(String id) => db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: id,
          name: 'П',
          technique: 'loom',
          contentKind: 'grid',
          lastWorkedAt: 0,
          createdAt: 0,
          updatedAt: 0,
          deviceId: 'd',
        ),
      );

  setUp(() async {
    db = createInMemoryDatabase();
    clock = FakeClock(DateTime.utc(2026, 11, 10, 10));
    repository = DriftWorkSessionRepository(
      dao: WorkSessionsDao(db),
      deviceIds: DriftDeviceIdProvider(dao: db.settingsDao, ids: FakeIdGenerator(), clock: clock),
      clock: clock,
      ids: UuidV7IdGenerator(clock: clock),
    );
    await insertProject('p1');
    await insertProject('p2');
  });

  test('start создаёт сессию без конца, со служебными колонками', () async {
    final WorkSession session = (await repository.start('p1', clock.now())).valueOrNull!;
    expect(session.projectId, 'p1');
    expect(session.endedAt, isNull);
    expect(session.duration, Duration.zero);
    final WorkSessionRow row = await db.select(db.workSessions).getSingle();
    expect(row.id, session.id);
    expect(row.startedAt, clock.now().millisecondsSinceEpoch);
    expect(row.endedAt, isNull);
    expect(row.deviceId, isNotEmpty);
    expect(row.createdAt, clock.now().millisecondsSinceEpoch);
  });

  test('touch двигает конец вперёд и не двигает назад (часы могли откатиться)', () async {
    final WorkSession session = (await repository.start('p1', clock.now())).valueOrNull!;
    final DateTime start = clock.now();
    expect((await repository.touch(session.id, start.add(const Duration(minutes: 5)))).isSuccess, isTrue);
    expect((await repository.touch(session.id, start.add(const Duration(minutes: 2)))).isSuccess, isTrue);
    expect((await repository.touch(session.id, start.subtract(const Duration(hours: 1)))).isSuccess, isTrue);
    final WorkSession loaded = (await repository.byProject('p1')).valueOrNull!.single;
    expect(loaded.duration, const Duration(minutes: 5));
    expect(loaded.startedAt.isUtc, isTrue);
    expect(loaded.endedAt!.isUtc, isTrue);
  });

  test('touch несуществующей сессии — NotFoundFailure', () async {
    expect((await repository.touch('нет', clock.now())).failureOrNull, isA<NotFoundFailure>());
  });

  test('byProject отдаёт сессии проекта по порядку начала, totalFor их суммирует', () async {
    final WorkSession a = (await repository.start('p1', clock.now())).valueOrNull!;
    await repository.touch(a.id, clock.now().add(const Duration(minutes: 10)));
    clock.advance(const Duration(hours: 1));
    final WorkSession b = (await repository.start('p1', clock.now())).valueOrNull!;
    await repository.touch(b.id, clock.now().add(const Duration(minutes: 20)));
    await repository.start('p2', clock.now());

    expect((await repository.byProject('p1')).valueOrNull!.map((s) => s.id), <String>[a.id, b.id]);
    expect((await repository.totalFor('p1')).valueOrNull, const Duration(minutes: 30));
    expect((await repository.totalFor('p2')).valueOrNull, Duration.zero);
    expect((await repository.totalFor('нет')).valueOrNull, Duration.zero);
  });

  test('deleteByProject ставит надгробие только сессиям этого проекта', () async {
    final WorkSession a = (await repository.start('p1', clock.now())).valueOrNull!;
    await repository.start('p2', clock.now());
    clock.advance(const Duration(minutes: 1));

    expect((await repository.deleteByProject('p1')).isSuccess, isTrue);

    expect((await repository.byProject('p1')).valueOrNull, isEmpty);
    expect((await repository.byProject('p2')).valueOrNull, hasLength(1));
    final WorkSessionRow row = await (db.select(db.workSessions)..where((t) => t.id.equals(a.id))).getSingle();
    expect(row.deletedAt, clock.now().millisecondsSinceEpoch);
    expect((await repository.touch(a.id, clock.now())).failureOrNull, isA<NotFoundFailure>());
  });

  test('сессия несуществующего проекта: ошибка хранилища, а не исключение', () async {
    expect((await repository.start('нет', clock.now())).failureOrNull, isA<StorageFailure>());
  });

  test('чистильщик удаляет сессии проекта любого вида содержимого', () async {
    await repository.start('p1', clock.now());
    final WorkSessionContentCleaner cleaner = WorkSessionContentCleaner(repository);
    expect(ContentKind.values.every(cleaner.supports), isTrue);
    final Project project = Project(
      id: 'p1',
      name: 'П',
      status: ProjectStatus.idea,
      craft: Craft.beading,
      technique: Technique.loom,
      contentKind: ContentKind.grid,
      notes: '',
      coverPath: null,
      lastWorkedAt: DateTime.utc(2026),
    );
    expect((await cleaner.remove(project)).isSuccess, isTrue);
    expect((await repository.byProject('p1')).valueOrNull, isEmpty);
  });
}
