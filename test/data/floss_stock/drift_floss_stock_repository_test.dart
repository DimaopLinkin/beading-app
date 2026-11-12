import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/floss_stock_dao.dart';
import 'package:beading/data/floss_stock/drift_floss_stock_repository.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/domain/floss_stock/floss_stock_entry.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_project_repository.dart';
import '../../support/in_memory_database.dart';

void main() {
  const CatalogRef dmc310 = CatalogRef(brand: 'DMC', code: '310');
  const CatalogRef anchor310 = CatalogRef(brand: 'Anchor', code: '310');

  late AppDatabase db;
  late FakeClock clock;
  late DriftFlossStockRepository repository;

  setUp(() {
    db = createInMemoryDatabase();
    clock = FakeClock(DateTime.utc(2026, 11, 12, 10));
    repository = DriftFlossStockRepository(
      dao: FlossStockDao(db),
      deviceIds: DriftDeviceIdProvider(dao: db.settingsDao, ids: FakeIdGenerator(), clock: clock),
      clock: clock,
      ids: UuidV7IdGenerator(clock: clock),
    );
  });

  test('пустой запас', () async {
    expect((await repository.all()).valueOrNull, isEmpty);
  });

  test('setSkeins добавляет нитку со служебными колонками', () async {
    expect((await repository.setSkeins(dmc310, 2.5)).isSuccess, isTrue);

    final FlossStockEntry entry = (await repository.all()).valueOrNull!.single;
    expect(entry.ref, dmc310);
    expect(entry.skeins, 2.5);
    expect(entry.updatedAt, clock.now());
    final FlossStockRow row = (await db.select(db.flossStock).get()).single;
    expect(row.createdAt, clock.now().millisecondsSinceEpoch);
    expect(row.deviceId, isNotEmpty);
  });

  test('повторный setSkeins обновляет ту же запись', () async {
    await repository.setSkeins(dmc310, 2);
    clock.advance(const Duration(minutes: 1));
    await repository.setSkeins(dmc310, 0.5);

    expect((await repository.all()).valueOrNull!.single.skeins, 0.5);
    final FlossStockRow row = (await db.select(db.flossStock).get()).single;
    expect(row.updatedAt, greaterThan(row.createdAt));
  });

  test('ноль убирает нитку надгробием, а новая запись снова её добавляет', () async {
    await repository.setSkeins(dmc310, 2);
    await repository.setSkeins(dmc310, 0);

    expect((await repository.all()).valueOrNull, isEmpty);
    expect((await db.select(db.flossStock).get()).single.deletedAt, isNotNull);

    await repository.setSkeins(dmc310, 1);
    expect((await repository.all()).valueOrNull!.single.skeins, 1);
  });

  test('ноль для нитки, которой нет, ничего не делает', () async {
    expect((await repository.setSkeins(dmc310, 0)).isSuccess, isTrue);
    expect(await db.select(db.flossStock).get(), isEmpty);
  });

  test('один номер разных брендов — разные нитки; порядок по бренду и номеру', () async {
    await repository.setSkeins(dmc310, 1);
    await repository.setSkeins(anchor310, 2);
    await repository.setSkeins(const CatalogRef(brand: 'DMC', code: '3721'), 3);

    expect((await repository.all()).valueOrNull!.map((e) => e.ref).toList(), <CatalogRef>[
      anchor310,
      dmc310,
      const CatalogRef(brand: 'DMC', code: '3721'),
    ]);
  });

  test('watchAll отдаёт запас при изменении', () async {
    final Future<void> done = expectLater(
      repository.watchAll(),
      emitsInOrder(<Matcher>[
        isEmpty,
        predicate<List<FlossStockEntry>>((l) => l.length == 1 && l.single.ref == dmc310 && l.single.skeins == 1),
      ]),
    );
    await Future<void>.delayed(Duration.zero);
    await repository.setSkeins(dmc310, 1);
    await done;
  });

  test('неверное число мотков: NaN, бесконечность, слишком много', () async {
    for (final double bad in <double>[double.nan, double.infinity, 1000]) {
      expect((await repository.setSkeins(dmc310, bad)).failureOrNull, isA<ValidationFailure>(), reason: '$bad');
    }
    expect(await db.select(db.flossStock).get(), isEmpty);
  });

  group('merge', () {
    final DateTime older = DateTime.utc(2026, 11);
    final DateTime newer = DateTime.utc(2026, 11, 20);

    test('добавляет нитки, которых нет, с временем из файла', () async {
      await repository.merge(<FlossStockEntry>[FlossStockEntry(ref: dmc310, skeins: 3, updatedAt: older)]);

      final FlossStockEntry entry = (await repository.all()).valueOrNull!.single;
      expect(entry.skeins, 3);
      expect(entry.updatedAt, older);
    });

    test('более свежая запись из файла заменяет локальную', () async {
      await repository.setSkeins(dmc310, 1);

      await repository.merge(<FlossStockEntry>[FlossStockEntry(ref: dmc310, skeins: 4, updatedAt: newer)]);

      expect((await repository.all()).valueOrNull!.single.skeins, 4);
    });

    test('более старая или равная запись из файла локальную не трогает', () async {
      await repository.setSkeins(dmc310, 1);
      final DateTime same = clock.now();

      await repository.merge(<FlossStockEntry>[
        FlossStockEntry(ref: dmc310, skeins: 4, updatedAt: older),
        FlossStockEntry(ref: dmc310, skeins: 5, updatedAt: same),
      ]);

      expect((await repository.all()).valueOrNull!.single.skeins, 1);
    });

    test('записи без времени и с неверным числом мотков пропускаются, нитка из запаса не стирается', () async {
      await repository.setSkeins(anchor310, 2);

      await repository.merge(<FlossStockEntry>[
        const FlossStockEntry(ref: dmc310, skeins: 3),
        FlossStockEntry(ref: dmc310, skeins: 0, updatedAt: newer),
        FlossStockEntry(ref: dmc310, skeins: 1000, updatedAt: newer),
        FlossStockEntry(ref: dmc310, skeins: double.nan, updatedAt: newer),
      ]);

      expect((await repository.all()).valueOrNull!.map((e) => e.ref), <CatalogRef>[anchor310]);
    });

    test('убранная раньше нитка возвращается записью из файла', () async {
      await repository.setSkeins(dmc310, 2);
      await repository.setSkeins(dmc310, 0);

      await repository.merge(<FlossStockEntry>[FlossStockEntry(ref: dmc310, skeins: 1, updatedAt: newer)]);

      expect((await repository.all()).valueOrNull!.single.skeins, 1);
    });
  });
}
