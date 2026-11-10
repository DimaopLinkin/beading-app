import 'package:beading/data/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Настоящая база SQLite в памяти; закрывается сама после теста.
AppDatabase createInMemoryDatabase() {
  final AppDatabase database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  return database;
}
