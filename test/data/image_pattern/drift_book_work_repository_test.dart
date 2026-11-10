import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/image_pattern/drift_book_work_repository.dart';
import 'package:beading/data/image_pattern/drift_image_pattern_repository.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/domain/image_pattern/book_work/page_viewport.dart';
import 'package:beading/domain/image_pattern/book_work/page_work.dart';
import 'package:beading/domain/image_pattern/book_work/ruler_state.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_project_repository.dart';
import '../../support/in_memory_database.dart';

const ImagePattern _pattern = ImagePattern(
  id: 'pat-1',
  projectId: 'proj-1',
  pages: <ImagePatternPage>[
    ImagePatternPage(id: 'pg-a', path: 'a.png', width: 100, height: 200),
    ImagePatternPage(id: 'pg-b', path: 'b.png', width: 100, height: 200),
  ],
);

const PageWork _workA = PageWork(
  pageId: 'pg-a',
  ruler: RulerState(top: 12.5, height: 6, step: 3, highlight: RulerHighlight.blue, row: 7),
  viewport: PageViewport(scale: 2.5, dx: -10, dy: -20.5),
);

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late DriftBookWorkRepository repository;
  late DriftImagePatternRepository patterns;

  setUp(() async {
    db = createInMemoryDatabase();
    clock = FakeClock(DateTime.utc(2026, 11, 10, 10));
    final DriftDeviceIdProvider deviceIds = DriftDeviceIdProvider(
      dao: db.settingsDao,
      ids: FakeIdGenerator(),
      clock: clock,
    );
    repository = DriftBookWorkRepository(dao: db.bookWorkDao, deviceIds: deviceIds, clock: clock);
    patterns = DriftImagePatternRepository(dao: db.imagePatternsDao, deviceIds: deviceIds, clock: clock);
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'proj-1',
            name: 'П',
            technique: 'loom',
            contentKind: 'image',
            lastWorkedAt: 0,
            createdAt: 0,
            updatedAt: 0,
            deviceId: 'd',
          ),
        );
    await patterns.save(_pattern);
  });

  test('схема, над которой не работали, даёт пустое состояние', () async {
    expect((await repository.load('pat-1')).valueOrNull, const BookWork());
  });

  test('состояние страницы читается точно так, как записано', () async {
    expect((await repository.savePage(_workA)).isSuccess, isTrue);

    final BookWork loaded = (await repository.load('pat-1')).valueOrNull!;

    expect(loaded.pages, <String, PageWork>{'pg-a': _workA});
    expect(loaded.currentPageId, isNull);
  });

  test('повторная запись заменяет состояние, время создания остаётся', () async {
    await repository.savePage(_workA);
    clock.advance(const Duration(minutes: 5));
    final PageWork moved = _workA.copyWith(ruler: _workA.ruler.previous(1000));

    await repository.savePage(moved);

    expect((await repository.load('pat-1')).valueOrNull!.pages['pg-a'], moved);
    final PageWorkStateRow row = await db.select(db.pageWorkStates).getSingle();
    expect(row.createdAt, DateTime.utc(2026, 11, 10, 10).millisecondsSinceEpoch);
    expect(row.updatedAt, clock.now().millisecondsSinceEpoch);
    expect(row.deviceId, isNotEmpty);
  });

  test('у каждой страницы своё состояние', () async {
    final PageWork workB = _workA.copyWith(ruler: RulerState.initial(200));
    await repository.savePage(_workA);
    await repository.savePage(PageWork(pageId: 'pg-b', ruler: workB.ruler));

    final BookWork loaded = (await repository.load('pat-1')).valueOrNull!;

    expect(loaded.pages.keys, unorderedEquals(<String>['pg-a', 'pg-b']));
    expect(loaded.pages['pg-a']!.ruler.row, 7);
    expect(loaded.pages['pg-b']!.ruler.row, 1);
  });

  test('открытая страница запоминается и заменяется', () async {
    await repository.saveCurrentPage(patternId: 'pat-1', pageId: 'pg-a');
    await repository.saveCurrentPage(patternId: 'pat-1', pageId: 'pg-b');

    expect((await repository.load('pat-1')).valueOrNull!.currentPageId, 'pg-b');
    expect(await db.select(db.bookWorkStates).get(), hasLength(1));
  });

  test('неизвестное имя цвета читается как жёлтый', () async {
    await repository.savePage(_workA);
    await db.customStatement("UPDATE page_work_states SET highlight = 'неизвестный'");

    expect((await repository.load('pat-1')).valueOrNull!.pages['pg-a']!.ruler.highlight, RulerHighlight.yellow);
  });

  test('открытой нельзя назвать страницу, которой нет в схеме (внешний ключ)', () async {
    final result = await repository.saveCurrentPage(patternId: 'pat-1', pageId: 'нет-такой');

    expect(result.isFailure, isTrue);
  });

  test('удаление схемы ставит надгробие и запомненной работе, наружу она не видна', () async {
    await repository.savePage(_workA);
    await repository.saveCurrentPage(patternId: 'pat-1', pageId: 'pg-a');
    clock.advance(const Duration(minutes: 1));

    await patterns.deleteByProject('proj-1');

    final PageWorkStateRow page = await db.select(db.pageWorkStates).getSingle();
    final BookWorkStateRow book = await db.select(db.bookWorkStates).getSingle();
    expect(page.deletedAt, clock.now().millisecondsSinceEpoch);
    expect(book.deletedAt, clock.now().millisecondsSinceEpoch);
    expect((await repository.load('pat-1')).valueOrNull, const BookWork());
  });
}
