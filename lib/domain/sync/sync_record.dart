import 'package:equatable/equatable.dart';

/// Запись для обмена между устройствами (ADR-0006): одна строка любой синхронизируемой таблицы.
///
/// Слияние сводит записи по паре ([entity], [syncId]), а не по локальному id строки.
class SyncRecord extends Equatable {
  const SyncRecord({
    required this.entity,
    required this.syncId,
    required this.updatedAt,
    required this.deviceId,
    this.deletedAt,
    this.data = const <String, Object?>{},
  });

  final String entity;

  /// Ключ слияния: см. таблицу «Ключи слияния» в ADR-0006.
  final String syncId;

  /// UTC, миллисекунды. Ставят репозитории по [MergePolicy.nextUpdatedAt].
  final int updatedAt;

  /// Надгробие: запись удалена. Нагрузка у надгробия пустая.
  final int? deletedAt;

  final String deviceId;

  /// JSON-нагрузка. Поле `v` — версия формата сущности (1, если не указано).
  final Map<String, Object?> data;

  SyncRecord copyWithData(Map<String, Object?> data, {required int updatedAt, required String deviceId}) => SyncRecord(
    entity: entity,
    syncId: syncId,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
    deviceId: deviceId,
    data: data,
  );

  bool get isDeleted => deletedAt != null;

  String get key => '$entity/$syncId';

  int get version => data['v'] is int ? data['v']! as int : 1;

  @override
  List<Object?> get props => <Object?>[entity, syncId, updatedAt, deletedAt, deviceId, data];
}
