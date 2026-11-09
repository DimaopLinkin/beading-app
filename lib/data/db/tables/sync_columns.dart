import 'package:drift/drift.dart';

/// Служебные колонки синхронизации ([data-and-sync.md]). Все времена — UTC, миллисекунды с эпохи.
///
/// Записывает их только репозиторий (через `Clock` и `DeviceIdProvider`).
mixin SyncColumns on Table {
  IntColumn get createdAt => integer()();

  /// Сравнение «кто новее» при слиянии.
  IntColumn get updatedAt => integer()();

  /// Мягкое удаление: надгробие доезжает до второго устройства.
  IntColumn get deletedAt => integer().nullable()();

  /// Устройство, последним менявшее запись.
  TextColumn get deviceId => text()();
}

/// Идентификатор записи: UUID v7 строкой, создаётся на клиенте (`IdGenerator`).
mixin UuidIdColumn on Table {
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
