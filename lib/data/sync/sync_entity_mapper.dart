import 'dart:convert';
import 'package:beading/core/id_generator.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/domain/sync/sync_record.dart';
import 'package:drift/drift.dart';

typedef Row = Map<String, Object?>;

/// Доступ к базе и генератору id для мапперов.
class SyncDbContext {
  SyncDbContext({required this.db, required this.ids});

  final AppDatabase db;
  final IdGenerator ids;

  Future<List<Row>> query(String sql, [List<Object?> args = const <Object?>[]]) async {
    final List<QueryRow> rows = await db
        .customSelect(sql, variables: <Variable<Object>>[for (final Object? a in args) _variable(a)])
        .get();
    return <Row>[for (final QueryRow r in rows) r.data];
  }

  Future<Row?> first(String sql, [List<Object?> args = const <Object?>[]]) async {
    final List<Row> rows = await query(sql, args);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> run(String sql, [List<Object?> args = const <Object?>[]]) =>
      db.customStatement(sql, <Object?>[for (final Object? a in args) a]);

  static Variable<Object> _variable(Object? value) => switch (value) {
    null => const Variable<Object>(null),
    final int v => Variable<int>(v),
    final double v => Variable<double>(v),
    final String v => Variable<String>(v),
    final Uint8List v => Variable<Uint8List>(v),
    _ => throw ArgumentError('Неподдерживаемый тип параметра: ${value.runtimeType}'),
  };
}

String? b64(Object? value) => value == null ? null : base64Encode(value as Uint8List);

Uint8List? unb64(Object? value) => value == null ? null : Uint8List.fromList(base64Decode(value as String));

/// Перевод строки таблицы в запись для обмена и обратно (ADR-0006). Один маппер на сущность.
abstract class SyncEntityMapper {
  SyncEntityMapper(this.ctx);

  final SyncDbContext ctx;

  String get entity;

  /// Родители применяются раньше детей: меньший rank — раньше.
  int get rank;

  /// Ключ родителя (`сущность/ключ`) или `null`.
  String? parentKey(SyncRecord record);

  /// Версия формата записи, которую умеет читать эта версия приложения.
  int get supportedVersion => 1;

  /// Ключи слияния всех строк таблицы (для первой постановки в очередь).
  Future<List<String>> allSyncIds();

  /// Текущее состояние записи (в том числе надгробие) или `null`, если строки нет.
  Future<SyncRecord?> read(String syncId);

  /// Применяет принятую запись. Родитель к этому моменту уже применён.
  Future<void> apply(SyncRecord record);

  /// Служебные колонки строки и поля нагрузки в одну запись.
  SyncRecord build(String syncId, Row row, Row fields) {
    final int? deletedAt = row['deleted_at'] as int?;
    return SyncRecord(
      entity: entity,
      syncId: syncId,
      updatedAt: row['updated_at']! as int,
      deletedAt: deletedAt,
      deviceId: row['device_id']! as String,
      data: deletedAt != null
          ? const <String, Object?>{}
          : <String, Object?>{'v': supportedVersion, 'created_at': row['created_at'], ...fields},
    );
  }

  /// Ставит надгробие строке и возвращает `true`; `false`, если строки нет.
  Future<bool> tombstone(String table, String where, List<Object?> args, SyncRecord r) async {
    final Row? existing = await ctx.first('SELECT 1 AS x FROM $table WHERE $where', args);
    if (existing == null) {
      return false;
    }
    await ctx.run(
      'UPDATE $table SET deleted_at = ?, updated_at = ?, device_id = ? WHERE $where',
      <Object?>[r.deletedAt, r.updatedAt, r.deviceId, ...args],
    );
    return true;
  }

  int createdAt(SyncRecord r) => (r.data['created_at'] as int?) ?? r.updatedAt;
}
