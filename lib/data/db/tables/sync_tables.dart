import 'package:drift/drift.dart';

/// Очередь изменений для отправки на сервер (ADR-0006): пара «сущность + ключ слияния».
/// Заполняется SQLite-триггерами (`SyncTriggers`), поэтому ловит любые пути записи.
@DataClassName('SyncOutboxRow')
class SyncOutbox extends Table {
  TextColumn get entity => text()();

  TextColumn get syncId => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{entity, syncId};
}

/// «Теневая» копия последней принятой с сервера нагрузки (ADR-0006): хранит поля, которых не знает эта версия
/// приложения, и записи, которые пока нельзя показать (родитель удалён или формат новее).
@DataClassName('SyncShadowRow')
class SyncShadow extends Table {
  TextColumn get entity => text()();

  TextColumn get syncId => text()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  TextColumn get deviceId => text()();

  /// JSON-нагрузка как пришла с сервера.
  TextColumn get data => text()();

  /// `true`, если запись не применена к таблицам (держится в ожидании родителя или обновления приложения).
  BoolColumn get held => boolean().withDefault(const Constant<bool>(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{entity, syncId};
}

/// Флаг «идёт применение входящих»: пока в таблице есть строка, триггеры очереди молчат.
@DataClassName('SyncApplyingRow')
class SyncApplying extends Table {
  IntColumn get flag => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{flag};
}
