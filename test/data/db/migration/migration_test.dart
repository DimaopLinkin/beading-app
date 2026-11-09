import 'package:beading/data/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_database/generated/schema.dart';

/// Тест миграций. Сейчас версия одна: проверяем, что дамп `drift_schemas/` совпадает с таблицами в коде.
/// При `schemaVersion++` запустите `dart run drift_dev make-migrations`: он добавит шаги и тесты со всех прошлых версий.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('схема v1 из дампа совпадает с AppDatabase', () async {
    final DatabaseConnection connection = await verifier.startAt(1);
    final AppDatabase database = AppDatabase(connection);
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 1);
  });
}
