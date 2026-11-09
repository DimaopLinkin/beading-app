import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/tables/settings_table.dart';
import 'package:drift/drift.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: <Type>[Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.attachedDatabase);

  Future<SettingRow?> find(String key) => (select(settings)..where((t) => t.key.equals(key))).getSingleOrNull();

  Stream<SettingRow?> watch(String key) => (select(settings)..where((t) => t.key.equals(key))).watchSingleOrNull();

  /// Записывает значение; у существующей строки сохраняет `created_at` и снимает надгробие.
  Future<void> upsert({required String key, required String value, required int nowMs, required String deviceId}) =>
      transaction(() async {
        final SettingRow? existing = await find(key);
        if (existing == null) {
          await into(settings).insert(
            SettingsCompanion.insert(key: key, value: value, createdAt: nowMs, updatedAt: nowMs, deviceId: deviceId),
          );
        } else {
          await (update(settings)..where((t) => t.key.equals(key))).write(
            SettingsCompanion(
              value: Value<String>(value),
              updatedAt: Value<int>(nowMs),
              deletedAt: const Value<int?>(null),
              deviceId: Value<String>(deviceId),
            ),
          );
        }
      });

  /// Мягко удаляет строку (надгробие); если строки нет — ничего не делает.
  Future<void> tombstone({required String key, required int nowMs, required String deviceId}) =>
      (update(settings)..where((t) => t.key.equals(key) & t.deletedAt.isNull())).write(
        SettingsCompanion(
          updatedAt: Value<int>(nowMs),
          deletedAt: Value<int?>(nowMs),
          deviceId: Value<String>(deviceId),
        ),
      );
}
