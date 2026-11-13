import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/grid_pattern/drift_cell_progress_store.dart';
import 'package:beading/data/grid_pattern/drift_grid_pattern_repository.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/in_memory_database.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late DriftGridPatternRepository repository;
  late DriftCellProgressStore store;

  setUp(() async {
    db = createInMemoryDatabase();
    clock = FakeClock(DateTime.utc(2026, 11, 11, 10));
    final DriftDeviceIdProvider devices = DriftDeviceIdProvider(
      dao: db.settingsDao,
      ids: FakeIdGenerator(),
      clock: clock,
    );
    repository = DriftGridPatternRepository(
      dao: db.gridPatternsDao,
      deviceIds: devices,
      clock: clock,
      ids: UuidV7IdGenerator(),
    );
    store = DriftCellProgressStore(dao: db.gridPatternsDao, deviceIds: devices, clock: clock, ids: UuidV7IdGenerator());
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'proj-1',
            name: 'П',
            technique: 'crossStitch',
            contentKind: 'grid',
            lastWorkedAt: 0,
            createdAt: 0,
            updatedAt: 0,
            deviceId: 'd',
          ),
        );
  });

  tearDown(() => db.close());

  GridPattern wide(int width, int height) => sampleGridPattern().copyWith(
    grid: Grid.fromCells(width: width, height: height, cells: List<int>.filled(width * height, 1)),
  );

  CellProgress marks(int width, List<CellPosition> cells) => CellProgress(width: width).withCells(cells, done: true);

  test('схемы нет: ошибка «не найдено»; без отметок прогресс пустой с шириной схемы', () async {
    expect((await store.load('нет')).failureOrNull, isA<NotFoundFailure>());
    expect((await store.writeBlocks('нет', <int, Uint8List>{0: Uint8List(32)})).failureOrNull, isA<NotFoundFailure>());
    await repository.save(wide(40, 20));
    final CellProgress loaded = (await store.load('pat-1')).valueOrNull!;
    expect(loaded.isEmpty, isTrue);
    expect(loaded.width, 40);
  });

  test('блоки записываются и читаются; пустые байты — снятие; повторная запись оживляет блок', () async {
    await repository.save(wide(40, 20));
    final CellProgress p = marks(40, const <CellPosition>[CellPosition(0, 0), CellPosition(17, 1)]);
    await store.writeBlocks('pat-1', p.blocks);
    expect((await store.load('pat-1')).valueOrNull, p);

    await store.writeBlocks('pat-1', <int, Uint8List>{1: Uint8List(0)});
    final CellProgress after = (await store.load('pat-1')).valueOrNull!;
    expect(after.isDone(17, 1), isFalse);
    expect(after.isDone(0, 0), isTrue);
    expect(await db.select(db.gridProgressCells).get(), hasLength(2), reason: 'блок остался надгробием');

    await store.writeBlocks('pat-1', p.blocks);
    expect((await store.load('pat-1')).valueOrNull, p);
    expect(await db.select(db.gridProgressCells).get(), hasLength(2), reason: 'блок оживлён, а не продублирован');
  });

  test('setCells: подряд посланные отметки одного блока не теряют друг друга', () async {
    await repository.save(wide(8, 8));
    await Future.wait(<Future<Object?>>[
      store.setCells('pat-1', const <CellPosition>[CellPosition(0, 0)], done: true),
      store.setCells('pat-1', const <CellPosition>[CellPosition(1, 0)], done: true),
      store.setCells('pat-1', const <CellPosition>[CellPosition(2, 0)], done: true),
    ]);
    expect((await store.load('pat-1')).valueOrNull!.count, 3);
    await store.setCells('pat-1', const <CellPosition>[CellPosition(1, 0)], done: false);
    expect((await store.load('pat-1')).valueOrNull!.count, 2);
    expect(
      (await store.setCells('нет', const <CellPosition>[CellPosition(0, 0)], done: true)).failureOrNull,
      isA<NotFoundFailure>(),
    );
  });

  test('запись блока ставит служебные колонки', () async {
    await repository.save(wide(8, 8));
    clock.advance(const Duration(minutes: 1));
    await store.writeBlocks('pat-1', marks(8, const <CellPosition>[CellPosition(1, 1)]).blocks);
    final GridProgressCellRecord row = await db.select(db.gridProgressCells).getSingle();
    expect(row.updatedAt, clock.now().millisecondsSinceEpoch);
    expect(row.deletedAt, isNull);
    expect(row.blockIndex, 0);
    expect(row.bits, hasLength(32));
  });

  test('watch отдаёт прогресс при каждом изменении и не повторяет одинаковый', () async {
    await repository.save(wide(8, 8));
    final List<CellProgress> seen = <CellProgress>[];
    final sub = store.watch('pat-1').listen(seen.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    await store.writeBlocks('pat-1', marks(8, const <CellPosition>[CellPosition(1, 1)]).blocks);
    await pumpEventQueue();
    expect(seen.last.isDone(1, 1), isTrue);
    final int count = seen.length;
    await store.writeBlocks('pat-1', marks(8, const <CellPosition>[CellPosition(1, 1)]).blocks);
    await pumpEventQueue();
    expect(seen, hasLength(count));
  });

  test('смена размера схемы отбрасывает клетки вне схемы, остальные остаются', () async {
    await repository.save(wide(40, 40));
    await store.writeBlocks(
      'pat-1',
      marks(40, const <CellPosition>[CellPosition(35, 1), CellPosition(2, 2), CellPosition(10, 30)]).blocks,
    );
    await repository.save(wide(20, 20));
    final CellProgress shrunk = (await store.load('pat-1')).valueOrNull!;
    expect(shrunk.width, 20);
    expect(shrunk.cells().toList(), const <CellPosition>[CellPosition(2, 2)]);

    await repository.save(wide(100, 20));
    final CellProgress grown = (await store.load('pat-1')).valueOrNull!;
    expect(grown.cells().toList(), const <CellPosition>[CellPosition(2, 2)]);
  });

  test('правка палитры без смены размера отметки не трогает', () async {
    await repository.save(wide(40, 20));
    await store.writeBlocks('pat-1', marks(40, const <CellPosition>[CellPosition(35, 1)]).blocks);
    await repository.save(wide(40, 20));
    expect((await store.load('pat-1')).valueOrNull!.isDone(35, 1), isTrue);
  });

  test('удаление проекта ставит надгробия блокам', () async {
    await repository.save(wide(8, 8));
    await store.writeBlocks('pat-1', marks(8, const <CellPosition>[CellPosition(1, 1)]).blocks);
    await repository.deleteByProject('proj-1');
    expect((await db.select(db.gridProgressCells).getSingle()).deletedAt, isNotNull);
    expect((await store.load('pat-1')).failureOrNull, isA<NotFoundFailure>());
  });
}
