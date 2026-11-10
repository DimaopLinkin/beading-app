import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/grid_pattern/drift_grid_pattern_repository.dart';
import 'package:beading/data/grid_pattern/drift_grid_progress_store.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/cell_metrics_codec.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/in_memory_database.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late DriftGridPatternRepository repository;
  late DriftGridProgressStore progress;

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
    progress = DriftGridProgressStore(
      dao: db.gridPatternsDao,
      deviceIds: devices,
      clock: clock,
      ids: UuidV7IdGenerator(),
    );
    await insertProject('proj-1');
  });

  group('схема', () {
    test(
      'сохранённая схема читается такой же: сетка, палитра с составом и отделкой, геометрия, размер ячейки',
      () async {
        final GridPattern pattern = sampleGridPattern();

        expect((await repository.save(pattern)).isSuccess, isTrue);

        final GridPattern loaded = (await repository.getByProject('proj-1')).valueOrNull!;
        expect(loaded, pattern);
        expect(loaded.palette.colors[1].components, hasLength(2));
        expect(loaded.palette.colors[0].finish, 'matte');
        expect(loaded.palette.colors[1].finish, isNull);
        expect(loaded.metrics, BeadSize.delica11);
        expect((loaded.geometry as PeyoteGeometry).drop, 2);
      },
    );

    test('все геометрии и произвольный размер ячейки переживают запись', () async {
      const List<GridGeometry> geometries = <GridGeometry>[
        GridGeometry.rectangular(),
        GridGeometry.brick(),
        GridGeometry.peyote(),
      ];
      for (final (int i, GridGeometry geometry) in geometries.indexed) {
        await insertProject('p$i');
        final GridPattern pattern = sampleGridPattern(id: 'pat$i', projectId: 'p$i').copyWith(
          geometry: geometry,
          metrics: const CustomCellMetrics(widthMm: 0.7, heightMm: 0.9),
        );
        await repository.save(pattern);

        expect((await repository.getByProject('p$i')).valueOrNull, pattern);
      }
    });

    test('служебные колонки проставляет репозиторий, слои пока пусты', () async {
      await repository.save(sampleGridPattern());

      final GridPatternRow row = await db.select(db.gridPatterns).getSingle();
      expect(row.createdAt, clock.now().millisecondsSinceEpoch);
      expect(row.updatedAt, clock.now().millisecondsSinceEpoch);
      expect(row.deviceId, isNotEmpty);
      expect(row.deletedAt, isNull);
      expect(row.layers, isNull);
      expect(row.layersCodecVersion, isNull);
      expect(row.cellsCodecVersion, 1);
      expect((row.width, row.height), (4, 3));
      final List<PatternColorRow> colors = await db.select(db.patternColors).get();
      expect(colors.map((c) => c.position).toSet(), <int>{0, 1});
      expect(colors.every((c) => c.deviceId == row.deviceId), isTrue);
    });

    test('слои вышивки сохраняются как есть и не теряются при правке сетки', () async {
      final GridLayersBlob layers = GridLayersBlob(codecVersion: 7, bytes: Uint8List.fromList(<int>[9, 8, 7]));
      final GridPattern pattern = sampleGridPattern().copyWith(layers: layers);
      await repository.save(pattern);

      final GridPattern loaded = (await repository.getByProject('proj-1')).valueOrNull!;
      expect(loaded.layers, layers);

      await repository.save(loaded.copyWith(grid: loaded.grid.withCell(0, 0, 2)));
      expect((await repository.getByProject('proj-1')).valueOrNull!.layers, layers);
    });

    test('схемы нет — NotFoundFailure', () async {
      expect((await repository.getByProject('proj-1')).failureOrNull, isA<NotFoundFailure>());
      expect((await repository.summaryByProject('proj-1')).failureOrNull, isA<NotFoundFailure>());
    });

    test('сводка отдаёт размеры без чтения сетки', () async {
      await repository.save(sampleGridPattern());

      final GridPatternSummary summary = (await repository.summaryByProject('proj-1')).valueOrNull!;
      expect(summary, const GridPatternSummary(id: 'pat-1', projectId: 'proj-1', width: 4, height: 3));
    });

    test('повторное сохранение заменяет сетку и палитру, палитра сокращается надгробиями', () async {
      await repository.save(sampleGridPattern());
      clock.advance(const Duration(minutes: 1));
      final PaletteSnapshot smaller = PaletteSnapshot(<PatternColor>[
        PatternColor(
          rgb: const Rgb(1, 2, 3),
          name: 'Синий',
          components: const <CatalogRef>[CatalogRef(brand: 'Toho', code: '8')],
          symbol: 'A',
        ),
      ]);
      final GridPattern edited = sampleGridPattern().copyWith(
        grid: Grid.fromCells(width: 4, height: 3, cells: List<int>.filled(12, 1)),
        palette: smaller,
      );

      expect((await repository.save(edited)).isSuccess, isTrue);

      expect((await repository.getByProject('proj-1')).valueOrNull, edited);
      final List<PatternColorRow> colors = await db.select(db.patternColors).get();
      expect(colors, hasLength(2));
      expect(colors.singleWhere((c) => c.position == 1).deletedAt, clock.now().millisecondsSinceEpoch);
      expect(await db.select(db.gridPatterns).get(), hasLength(1));
    });

    test('цвет, вернувшийся в палитру, оживает на том же месте', () async {
      await repository.save(sampleGridPattern());
      await repository.save(
        sampleGridPattern().copyWith(
          grid: Grid.empty(width: 4, height: 3),
          palette: PaletteSnapshot(<PatternColor>[samplePalette().colors.first]),
        ),
      );
      await repository.save(sampleGridPattern());

      expect((await repository.getByProject('proj-1')).valueOrNull, sampleGridPattern());
      expect(await db.select(db.patternColors).get(), hasLength(2));
    });

    test('неизменившиеся цвета при сохранении не получают новый updated_at', () async {
      await repository.save(sampleGridPattern());
      final int created = clock.now().millisecondsSinceEpoch;
      clock.advance(const Duration(minutes: 5));

      await repository.save(sampleGridPattern());

      final List<PatternColorRow> colors = await db.select(db.patternColors).get();
      expect(colors.every((c) => c.updatedAt == created), isTrue);
      expect((await db.select(db.gridPatterns).getSingle()).updatedAt, clock.now().millisecondsSinceEpoch);
    });

    test('ошибка при записи палитры откатывает всю схему', () async {
      await repository.save(sampleGridPattern());
      await db.customStatement('''
        CREATE TRIGGER fail_color BEFORE INSERT ON pattern_colors WHEN NEW.name = 'Взрыв'
        BEGIN SELECT RAISE(ABORT, 'нельзя'); END
      ''');
      final GridPattern broken = sampleGridPattern().copyWith(
        grid: Grid.empty(width: 2, height: 2),
        palette: PaletteSnapshot(<PatternColor>[
          ...samplePalette().colors,
          PatternColor(
            rgb: const Rgb(0, 0, 0),
            name: 'Взрыв',
            components: const <CatalogRef>[CatalogRef(brand: 'X', code: '1')],
            symbol: 'C',
          ),
        ]),
      );

      expect((await repository.save(broken)).failureOrNull, isA<StorageFailure>());

      expect((await repository.getByProject('proj-1')).valueOrNull, sampleGridPattern());
    });

    test('новая схема с ошибкой палитры не оставляет полу-записанной строки', () async {
      await db.customStatement('''
        CREATE TRIGGER fail_color BEFORE INSERT ON pattern_colors WHEN NEW.name = 'Красный'
        BEGIN SELECT RAISE(ABORT, 'нельзя'); END
      ''');

      expect((await repository.save(sampleGridPattern())).failureOrNull, isA<StorageFailure>());

      expect(await db.select(db.gridPatterns).get(), isEmpty);
      expect(await db.select(db.patternColors).get(), isEmpty);
    });

    test('вторая схема у того же проекта — StorageFailure, первая цела', () async {
      await repository.save(sampleGridPattern());

      expect((await repository.save(sampleGridPattern(id: 'pat-2'))).failureOrNull, isA<StorageFailure>());

      expect((await repository.getByProject('proj-1')).valueOrNull!.id, 'pat-1');
    });

    test('сохранение чужой или удалённой схемы — NotFoundFailure', () async {
      await repository.save(sampleGridPattern());
      await repository.deleteByProject('proj-1');

      expect((await repository.save(sampleGridPattern())).failureOrNull, isA<NotFoundFailure>());
    });

    test('размер ячейки, который нельзя записать, отклоняется и ничего не пишет', () async {
      final GridPattern bad = sampleGridPattern().copyWith(metrics: const _Unknown());

      expect((await repository.save(bad)).failureOrNull, isA<ValidationFailure>());
      expect(await db.select(db.gridPatterns).get(), isEmpty);
    });

    test('удаление ставит надгробия схеме, палитре и отметкам; повторное удаление — успех', () async {
      await repository.save(sampleGridPattern());
      await progress.markRow('pat-1', 1);
      clock.advance(const Duration(minutes: 1));

      expect((await repository.deleteByProject('proj-1')).isSuccess, isTrue);

      final int now = clock.now().millisecondsSinceEpoch;
      expect((await db.select(db.gridPatterns).getSingle()).deletedAt, now);
      expect((await db.select(db.patternColors).get()).every((c) => c.deletedAt == now), isTrue);
      expect((await db.select(db.gridProgressRows).get()).every((r) => r.deletedAt == now), isTrue);
      expect((await repository.getByProject('proj-1')).failureOrNull, isA<NotFoundFailure>());
      expect((await repository.deleteByProject('proj-1')).isSuccess, isTrue);
      expect((await repository.deleteByProject('нет такого')).isSuccess, isTrue);
    });

    test('повреждённые данные дают ошибку, а не исключение', () async {
      await repository.save(sampleGridPattern());
      await db.update(db.gridPatterns).write(const GridPatternsCompanion(geometry: Value<String>('hex')));
      expect((await repository.getByProject('proj-1')).failureOrNull, isA<ValidationFailure>());

      await db
          .update(db.gridPatterns)
          .write(
            const GridPatternsCompanion(geometry: Value<String>('rectangular'), cellMetrics: Value<String>('мусор')),
          );
      expect((await repository.getByProject('proj-1')).failureOrNull, isA<ValidationFailure>());

      await db
          .update(db.gridPatterns)
          .write(
            GridPatternsCompanion(
              cellMetrics: const Value<String>('{"kind":"custom","widthMm":1,"heightMm":1}'),
              cells: Value<Uint8List>(Uint8List.fromList(<int>[1, 2])),
            ),
          );
      expect((await repository.getByProject('proj-1')).failureOrNull, isA<ValidationFailure>());
    });

    test('неизвестная версия кодека сетки и неверный размер — StorageFailure', () async {
      await repository.save(sampleGridPattern());
      await db.update(db.gridPatterns).write(const GridPatternsCompanion(cellsCodecVersion: Value<int>(9)));
      expect((await repository.getByProject('proj-1')).failureOrNull, isA<StorageFailure>());

      await db
          .update(db.gridPatterns)
          .write(
            const GridPatternsCompanion(cellsCodecVersion: Value<int>(1), width: Value<int>(5)),
          );
      expect((await repository.getByProject('proj-1')).failureOrNull, isA<StorageFailure>());
    });

    test('повреждённый состав цвета — StorageFailure', () async {
      await repository.save(sampleGridPattern());
      for (final String bad in <String>[
        'не json',
        '[]',
        '[1]',
        '[{"brand":"A"}]',
        '[{"brand":"A","code":"1"},{"brand":"B","code":"2"},{"brand":"C","code":"3"}]',
      ]) {
        await db.update(db.patternColors).write(PatternColorsCompanion(components: Value<String>(bad)));
        expect((await repository.getByProject('proj-1')).failureOrNull, isA<StorageFailure>(), reason: bad);
      }
    });

    test('схема 1×1 сохраняется и читается', () async {
      final GridPattern tiny = sampleGridPattern().copyWith(
        grid: Grid.fromCells(width: 1, height: 1, cells: const <int>[2]),
      );

      await repository.save(tiny);

      expect((await repository.getByProject('proj-1')).valueOrNull, tiny);
    });

    test('схема 100×400 сохраняется и читается быстрее 50 мс каждая операция', () async {
      final List<int> cells = List<int>.generate(100 * 400, (i) => (i ~/ 7 + i ~/ 100) % 6);
      final GridPattern big = GridPattern(
        id: 'big',
        projectId: 'proj-1',
        geometry: const GridGeometry.rectangular(),
        metrics: BeadSize.delica11,
        grid: Grid.fromCells(width: 100, height: 400, cells: cells),
        palette: PaletteSnapshot(<PatternColor>[
          for (int i = 0; i < 5; i++)
            PatternColor(
              rgb: Rgb(i * 40, 10, 10),
              name: 'Цвет $i',
              components: <CatalogRef>[CatalogRef(brand: 'Miyuki', code: '$i')],
              symbol: String.fromCharCode(65 + i),
            ),
        ]),
      );

      final Stopwatch save = Stopwatch()..start();
      final bool saved = (await repository.save(big)).isSuccess;
      save.stop();
      final Stopwatch load = Stopwatch()..start();
      final GridPattern? loaded = (await repository.getByProject('proj-1')).valueOrNull;
      load.stop();

      expect(saved, isTrue);
      expect(loaded, big);
      expect(save.elapsedMilliseconds, lessThan(50), reason: 'сохранение ${save.elapsedMilliseconds} мс');
      expect(load.elapsedMilliseconds, lessThan(50), reason: 'чтение ${load.elapsedMilliseconds} мс');
    });
  });

  group('поток изменений', () {
    test('поток отдаёт null, затем схему, затем правки; отметка ряда подписчика не будит', () async {
      final List<GridPattern?> seen = <GridPattern?>[];
      final subscription = repository.watchByProject('proj-1').listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await repository.save(sampleGridPattern());
      await pumpEventQueue();
      await progress.markRow('pat-1', 0);
      await pumpEventQueue();
      final GridPattern edited = sampleGridPattern().copyWith(grid: Grid.empty(width: 4, height: 3));
      await repository.save(edited);
      await pumpEventQueue();
      await repository.deleteByProject('proj-1');
      await pumpEventQueue();

      expect(seen, <GridPattern?>[null, sampleGridPattern(), edited, null]);
    });
  });

  group('прогресс', () {
    setUp(() => repository.save(sampleGridPattern()));

    test('у схемы без отметок прогресс пуст', () async {
      expect((await progress.load('pat-1')).valueOrNull, GridProgress());
    });

    test('отметки рядов — множество: повтор не удваивает, снятие убирает', () async {
      await progress.markRow('pat-1', 2);
      await progress.markRow('pat-1', 0);
      await progress.markRow('pat-1', 2);

      expect((await progress.load('pat-1')).valueOrNull!.completedRows, <int>{0, 2});
      expect(await db.select(db.gridProgressRows).get(), hasLength(2));

      await progress.unmarkRow('pat-1', 2);
      expect((await progress.load('pat-1')).valueOrNull!.completedRows, <int>{0});
    });

    test('снять неотмеченный ряд — успех; повторная отметка оживляет ту же строку', () async {
      expect((await progress.unmarkRow('pat-1', 1)).isSuccess, isTrue);

      await progress.markRow('pat-1', 1);
      clock.advance(const Duration(minutes: 1));
      await progress.unmarkRow('pat-1', 1);
      clock.advance(const Duration(minutes: 1));
      await progress.markRow('pat-1', 1);

      final List<GridProgressRowRecord> rows = await db.select(db.gridProgressRows).get();
      expect(rows, hasLength(1));
      expect(rows.single.deletedAt, isNull);
      expect(rows.single.completedAt, clock.now().millisecondsSinceEpoch);
      expect((await progress.load('pat-1')).valueOrNull!.completedRows, <int>{1});
    });

    test('«остановилась здесь»: ряд и бусина запоминаются и заменяются', () async {
      await progress.setCurrent('pat-1', row: 1, bead: 3);
      expect(
        (await progress.load('pat-1')).valueOrNull,
        GridProgress(currentRow: 1, currentBead: 3),
      );

      await progress.setCurrent('pat-1', row: 2);
      expect((await progress.load('pat-1')).valueOrNull, GridProgress(currentRow: 2));
    });

    test('прогресс не мешает записи схемы и переживает правку палитры', () async {
      await progress.markRow('pat-1', 1);
      await progress.setCurrent('pat-1', row: 1, bead: 2);

      await repository.save(
        sampleGridPattern().copyWith(
          palette: PaletteSnapshot(<PatternColor>[samplePalette().colors.first]),
          grid: Grid.empty(width: 4, height: 3),
        ),
      );

      expect(
        (await progress.load('pat-1')).valueOrNull,
        GridProgress(completedRows: const <int>{1}, currentRow: 1, currentBead: 2),
      );
    });

    test('схема стала ниже и уже — отметки и позиция за её краем снимаются', () async {
      await progress.markRow('pat-1', 0);
      await progress.markRow('pat-1', 2);
      await progress.setCurrent('pat-1', row: 2, bead: 3);

      await repository.save(
        sampleGridPattern().copyWith(
          grid: Grid.fromCells(width: 4, height: 2, cells: const <int>[1, 2, 0, 1, 2, 2, 1, 0]),
        ),
      );

      expect((await progress.load('pat-1')).valueOrNull, GridProgress(completedRows: const <int>{0}));

      await progress.setCurrent('pat-1', row: 1, bead: 3);
      await repository.save(
        sampleGridPattern().copyWith(grid: Grid.fromCells(width: 3, height: 2, cells: const <int>[1, 2, 0, 1, 2, 2])),
      );

      expect((await progress.load('pat-1')).valueOrNull, GridProgress(completedRows: const <int>{0}, currentRow: 1));
    });

    test('служебные колонки отметок и сдвиг updated_at у схемы при «остановилась здесь»', () async {
      clock.advance(const Duration(minutes: 1));
      await progress.markRow('pat-1', 0);
      await progress.setCurrent('pat-1', row: 0, bead: 1);

      final GridProgressRowRecord row = await db.select(db.gridProgressRows).getSingle();
      expect(row.createdAt, clock.now().millisecondsSinceEpoch);
      expect(row.deviceId, isNotEmpty);
      expect((await db.select(db.gridPatterns).getSingle()).updatedAt, clock.now().millisecondsSinceEpoch);
    });

    test('несуществующая и удалённая схема — NotFoundFailure', () async {
      expect((await progress.markRow('нет', 0)).failureOrNull, isA<NotFoundFailure>());
      expect((await progress.unmarkRow('нет', 0)).failureOrNull, isA<NotFoundFailure>());
      expect((await progress.setCurrent('нет', row: 0)).failureOrNull, isA<NotFoundFailure>());
      expect((await progress.load('нет')).failureOrNull, isA<NotFoundFailure>());

      await repository.deleteByProject('proj-1');
      expect((await progress.markRow('pat-1', 0)).failureOrNull, isA<NotFoundFailure>());
    });

    test('удаление схемы при живой подписке даёт пустой прогресс, а не ошибку', () async {
      await progress.markRow('pat-1', 1);
      final List<GridProgress> seen = <GridProgress>[];
      final List<Object> errors = <Object>[];
      final subscription = progress.watch('pat-1').listen(seen.add, onError: errors.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await repository.deleteByProject('proj-1');
      await pumpEventQueue();

      expect(errors, isEmpty);
      expect(seen.last, GridProgress());
    });

    test('поток прогресса отдаёт текущее состояние и только реальные изменения', () async {
      final List<GridProgress> seen = <GridProgress>[];
      final subscription = progress.watch('pat-1').listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await progress.markRow('pat-1', 1);
      await pumpEventQueue();
      await progress.markRow('pat-1', 1);
      await pumpEventQueue();
      await progress.setCurrent('pat-1', row: 1);
      await pumpEventQueue();

      expect(seen, <GridProgress>[
        GridProgress(),
        GridProgress(completedRows: const <int>{1}),
        GridProgress(completedRows: const <int>{1}, currentRow: 1),
      ]);
    });
  });
}

class _Unknown implements CellMetrics {
  const _Unknown();

  @override
  double get widthMm => 1;

  @override
  double get heightMm => 1;
}
