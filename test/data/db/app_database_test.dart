import 'package:beading/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_database.dart';

void main() {
  test('после открытия включены внешние ключи', () async {
    final AppDatabase database = createInMemoryDatabase();

    final row = await database.customSelect('PRAGMA foreign_keys').getSingle();

    expect(row.read<int>('foreign_keys'), 1);
  });
}
