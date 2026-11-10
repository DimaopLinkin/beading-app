import 'package:beading/core/failure.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/image_pattern/drift_image_pattern_repository.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_project_repository.dart';
import '../../support/in_memory_database.dart';

const ImagePattern _pattern = ImagePattern(
  id: 'pat-1',
  projectId: 'proj-1',
  pages: <ImagePatternPage>[
    ImagePatternPage(id: 'pg-b', path: 'book_patterns/pat-1/pg-b.png', width: 10, height: 20),
    ImagePatternPage(id: 'pg-a', path: 'book_patterns/pat-1/pg-a.png', width: 30, height: 40),
  ],
);

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late DriftImagePatternRepository repository;

  Future<void> insertProject(String id) => db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: id,
          name: 'П',
          technique: 'loom',
          contentKind: 'image',
          lastWorkedAt: 0,
          createdAt: 0,
          updatedAt: 0,
          deviceId: 'd',
        ),
      );

  setUp(() async {
    db = createInMemoryDatabase();
    clock = FakeClock(DateTime.utc(2026, 11, 9, 10));
    repository = DriftImagePatternRepository(
      dao: db.imagePatternsDao,
      deviceIds: DriftDeviceIdProvider(dao: db.settingsDao, ids: FakeIdGenerator(), clock: clock),
      clock: clock,
    );
    await insertProject('proj-1');
  });

  test('сохранённая схема читается с теми же страницами в том же порядке', () async {
    expect((await repository.save(_pattern)).isSuccess, isTrue);

    expect((await repository.getByProject('proj-1')).valueOrNull, _pattern);
  });

  test('служебные колонки схемы и страниц проставляет репозиторий', () async {
    await repository.save(_pattern);

    final ImagePatternRow pattern = await db.select(db.imagePatterns).getSingle();
    expect(pattern.createdAt, clock.now().millisecondsSinceEpoch);
    expect(pattern.deviceId, isNotEmpty);
    expect(pattern.deletedAt, isNull);
    final List<ImagePatternPageRow> pages = await db.select(db.imagePatternPages).get();
    expect(pages.map((p) => p.position).toSet(), <int>{0, 1});
    expect(pages.every((p) => p.updatedAt == clock.now().millisecondsSinceEpoch), isTrue);
  });

  test('схемы нет — NotFoundFailure', () async {
    expect((await repository.getByProject('proj-1')).failureOrNull, isA<NotFoundFailure>());
  });

  test('вторая схема того же проекта — StorageFailure, первая цела', () async {
    await repository.save(_pattern);

    final result = await repository.save(
      const ImagePattern(
        id: 'pat-2',
        projectId: 'proj-1',
        pages: <ImagePatternPage>[ImagePatternPage(id: 'x', path: 'x.png', width: 1, height: 1)],
      ),
    );

    expect(result.failureOrNull, isA<StorageFailure>());
    expect((await repository.getByProject('proj-1')).valueOrNull, _pattern);
    expect(await db.select(db.imagePatternPages).get(), hasLength(2));
  });

  test('схема несуществующего проекта не сохраняется (внешний ключ)', () async {
    final result = await repository.save(
      const ImagePattern(id: 'p', projectId: 'нет', pages: <ImagePatternPage>[]),
    );

    expect(result.failureOrNull, isA<StorageFailure>());
  });

  test('сбой на странице откатывает всю схему', () async {
    final result = await repository.save(
      const ImagePattern(
        id: 'pat-3',
        projectId: 'proj-1',
        pages: <ImagePatternPage>[
          ImagePatternPage(id: 'same', path: 'a.png', width: 1, height: 1),
          ImagePatternPage(id: 'same', path: 'b.png', width: 1, height: 1),
        ],
      ),
    );

    expect(result.failureOrNull, isA<StorageFailure>());
    expect(await db.select(db.imagePatterns).get(), isEmpty);
  });

  test('удаление ставит надгробие схеме и страницам, наружу они не видны', () async {
    await repository.save(_pattern);
    clock.advance(const Duration(minutes: 1));

    expect((await repository.deleteByProject('proj-1')).isSuccess, isTrue);

    expect((await repository.getByProject('proj-1')).failureOrNull, isA<NotFoundFailure>());
    final ImagePatternRow pattern = await db.select(db.imagePatterns).getSingle();
    expect(pattern.deletedAt, clock.now().millisecondsSinceEpoch);
    final List<ImagePatternPageRow> pages = await db.select(db.imagePatternPages).get();
    expect(pages.every((p) => p.deletedAt == clock.now().millisecondsSinceEpoch), isTrue);
  });

  test('удаление без схемы — успех', () async {
    expect((await repository.deleteByProject('proj-1')).isSuccess, isTrue);
  });
}
