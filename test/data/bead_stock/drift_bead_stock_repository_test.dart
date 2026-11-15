import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/data/bead_stock/drift_bead_stock_repository.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/bead_stock_dao.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/domain/bead_stock/bead_stock_entry.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_project_repository.dart';
import '../../support/in_memory_database.dart';

void main() {
  const CatalogRef delica10 = CatalogRef(brand: 'Miyuki', code: 'DB0010');
  const CatalogRef toho10 = CatalogRef(brand: 'Toho', code: 'DB0010');

  late AppDatabase db;
  late FakeClock clock;
  late DriftBeadStockRepository repository;

  setUp(() {
    db = createInMemoryDatabase();
    clock = FakeClock(DateTime.utc(2026, 11, 12, 10));
    repository = DriftBeadStockRepository(
      dao: BeadStockDao(db),
      deviceIds: DriftDeviceIdProvider(dao: db.settingsDao, ids: FakeIdGenerator(), clock: clock),
      clock: clock,
      ids: UuidV7IdGenerator(clock: clock),
    );
  });

  test('пустой запас', () async {
    expect((await repository.all()).valueOrNull, isEmpty);
  });

  test('setGrams добавляет цвет со служебными колонками', () async {
    expect((await repository.setGrams(delica10, 2.5)).isSuccess, isTrue);

    final BeadStockEntry entry = (await repository.all()).valueOrNull!.single;
    expect(entry.ref, delica10);
    expect(entry.grams, 2.5);
    expect(entry.updatedAt, clock.now());
    final BeadStockRow row = (await db.select(db.beadStock).get()).single;
    expect(row.createdAt, clock.now().millisecondsSinceEpoch);
    expect(row.deviceId, isNotEmpty);
  });

  test('повторный setGrams обновляет ту же запись', () async {
    await repository.setGrams(delica10, 2);
    clock.advance(const Duration(minutes: 1));
    await repository.setGrams(delica10, 0.5);

    expect((await repository.all()).valueOrNull!.single.grams, 0.5);
    final BeadStockRow row = (await db.select(db.beadStock).get()).single;
    expect(row.updatedAt, greaterThan(row.createdAt));
  });

  test('ноль убирает цвет надгробием, а новая запись снова её добавляет', () async {
    await repository.setGrams(delica10, 2);
    await repository.setGrams(delica10, 0);

    expect((await repository.all()).valueOrNull, isEmpty);
    expect((await db.select(db.beadStock).get()).single.deletedAt, isNotNull);

    await repository.setGrams(delica10, 1);
    expect((await repository.all()).valueOrNull!.single.grams, 1);
  });

  test('ноль для цвета, которой нет, ничего не делает', () async {
    expect((await repository.setGrams(delica10, 0)).isSuccess, isTrue);
    expect(await db.select(db.beadStock).get(), isEmpty);
  });

  test('один номер разных брендов — разные цвета; порядок по бренду и номеру', () async {
    await repository.setGrams(delica10, 1);
    await repository.setGrams(toho10, 2);
    await repository.setGrams(const CatalogRef(brand: 'Miyuki', code: 'DB0011'), 3);

    expect((await repository.all()).valueOrNull!.map((e) => e.ref).toList(), <CatalogRef>[
      delica10,
      const CatalogRef(brand: 'Miyuki', code: 'DB0011'),
      toho10,
    ]);
  });

  test('watchAll отдаёт запас при изменении', () async {
    final Future<void> done = expectLater(
      repository.watchAll(),
      emitsInOrder(<Matcher>[
        isEmpty,
        predicate<List<BeadStockEntry>>((l) => l.length == 1 && l.single.ref == delica10 && l.single.grams == 1),
      ]),
    );
    await Future<void>.delayed(Duration.zero);
    await repository.setGrams(delica10, 1);
    await done;
  });

  test('неверное число граммов: NaN, бесконечность, слишком много', () async {
    for (final double bad in <double>[double.nan, double.infinity, 10000]) {
      expect((await repository.setGrams(delica10, bad)).failureOrNull, isA<ValidationFailure>(), reason: '$bad');
    }
    expect(await db.select(db.beadStock).get(), isEmpty);
  });

  group('merge', () {
    final DateTime older = DateTime.utc(2026, 11);
    final DateTime newer = DateTime.utc(2026, 11, 20);

    test('добавляет цвета, которых нет, с временем из файла', () async {
      await repository.merge(<BeadStockEntry>[BeadStockEntry(ref: delica10, grams: 3, updatedAt: older)]);

      final BeadStockEntry entry = (await repository.all()).valueOrNull!.single;
      expect(entry.grams, 3);
      expect(entry.updatedAt, older);
    });

    test('более свежая запись из файла заменяет локальную', () async {
      await repository.setGrams(delica10, 1);

      await repository.merge(<BeadStockEntry>[BeadStockEntry(ref: delica10, grams: 4, updatedAt: newer)]);

      expect((await repository.all()).valueOrNull!.single.grams, 4);
    });

    test('более старая или равная запись из файла локальную не трогает', () async {
      await repository.setGrams(delica10, 1);
      final DateTime same = clock.now();

      await repository.merge(<BeadStockEntry>[
        BeadStockEntry(ref: delica10, grams: 4, updatedAt: older),
        BeadStockEntry(ref: delica10, grams: 5, updatedAt: same),
      ]);

      expect((await repository.all()).valueOrNull!.single.grams, 1);
    });

    test('записи без времени и с неверным числом граммов пропускаются, цвет из запаса не стирается', () async {
      await repository.setGrams(toho10, 2);

      await repository.merge(<BeadStockEntry>[
        const BeadStockEntry(ref: delica10, grams: 3),
        BeadStockEntry(ref: delica10, grams: 0, updatedAt: newer),
        BeadStockEntry(ref: delica10, grams: 10000, updatedAt: newer),
        BeadStockEntry(ref: delica10, grams: double.nan, updatedAt: newer),
      ]);

      expect((await repository.all()).valueOrNull!.map((e) => e.ref), <CatalogRef>[toho10]);
    });

    test('убранный раньше цвет возвращается записью из файла', () async {
      await repository.setGrams(delica10, 2);
      await repository.setGrams(delica10, 0);

      await repository.merge(<BeadStockEntry>[BeadStockEntry(ref: delica10, grams: 1, updatedAt: newer)]);

      expect((await repository.all()).valueOrNull!.single.grams, 1);
    });
  });
}
