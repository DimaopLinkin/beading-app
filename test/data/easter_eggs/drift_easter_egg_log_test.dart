import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/easter_eggs/drift_easter_egg_log.dart';
import 'package:beading/domain/easter_eggs/egg_group.dart';
import 'package:beading/domain/easter_eggs/egg_log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_database.dart';

void main() {
  late AppDatabase database;
  late DriftEasterEggLog log;

  setUp(() {
    database = createInMemoryDatabase();
    log = DriftEasterEggLog(database.easterEggLogDao);
  });

  test('пустой журнал — пустой список', () async {
    expect((await log.all()).valueOrNull, isEmpty);
  });

  test('записанное читается обратно в порядке добавления, время — локальное', () async {
    final EggLogEntry first = EggLogEntry(
      group: EggGroup.rows,
      eggId: 'rows:a',
      shownAt: DateTime(2026, 11, 9, 12, 30),
    );
    final EggLogEntry second = EggLogEntry(group: EggGroup.secret, eggId: 'secret:б', shownAt: DateTime(2026, 11, 10));

    await log.add(first);
    await log.add(second);

    expect((await log.all()).valueOrNull, <EggLogEntry>[first, second]);
  });

  test('неизвестная группа в базе (из будущей версии) пропускается', () async {
    await database.easterEggLogDao.insertRow(group: 'future', eggId: 'future:x', shownAtMs: 1);
    final EggLogEntry ok = EggLogEntry(group: EggGroup.completed, eggId: 'completed:x', shownAt: DateTime(2026));
    await log.add(ok);

    expect((await log.all()).valueOrNull, <EggLogEntry>[ok]);
  });

  test('ошибка базы — Failure, а не исключение', () async {
    await database.customStatement('DROP TABLE easter_egg_log');

    expect((await log.all()).isFailure, isTrue);
    expect(
      (await log.add(EggLogEntry(group: EggGroup.rows, eggId: 'rows:a', shownAt: DateTime(2026)))).isFailure,
      isTrue,
    );
  });
}
