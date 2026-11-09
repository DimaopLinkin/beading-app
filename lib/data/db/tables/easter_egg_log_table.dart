import 'package:drift/drift.dart';

/// История показанных комплиментов. Локальная: служебных колонок синхронизации нет ([data-and-sync.md]).
@DataClassName('EasterEggLogRow')
class EasterEggLogEntries extends Table {
  @override
  String get tableName => 'easter_egg_log';

  IntColumn get id => integer().autoIncrement()();

  /// Имя `EggGroup`.
  TextColumn get eggGroup => text()();

  /// `Compliment.id`.
  TextColumn get eggId => text()();

  /// Локальное время показа, миллисекунды с эпохи.
  IntColumn get shownAt => integer()();
}
