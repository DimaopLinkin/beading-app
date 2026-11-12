import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:beading/data/sync/record_transport.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/sync/sync_record.dart';
import 'package:crypto/crypto.dart';

/// Какие поля записи лежат файлами в Storage, а не в строке (ADR-0006, R-08): правило по полю, а не по размеру.
class BlobField {
  const BlobField(this.entity, this.field);

  final String entity;
  final String field;
}

/// Выносит большие нагрузки записи в Storage перед отправкой и возвращает их при приёме.
///
/// Объект называется по хешу содержимого и неизменяем: неизменившийся файл повторно не загружается.
/// Нагрузка сжимается gzip. Если файл не скачался, исключение прерывает pull до применения записи.
class BlobExternalizer {
  BlobExternalizer({required this.blobs, required this.files});

  /// Поля с base64-нагрузкой внутри `data`.
  static const List<BlobField> inlineFields = <BlobField>[
    BlobField('grid_pattern', 'cells'),
    BlobField('grid_pattern', 'layers'),
  ];

  /// Страницы схем из книг: файл лежит в Application Support по пути из `data.path`, в записи — ссылка `file`.
  static const String pageEntity = 'image_pattern_page';

  final BlobTransport blobs;
  final FileStore files;

  Future<SyncRecord> externalize(SyncRecord record) async {
    if (record.isDeleted) {
      return record;
    }
    final Map<String, Object?> data = <String, Object?>{...record.data};
    for (final BlobField f in inlineFields.where((f) => f.entity == record.entity)) {
      final Object? value = data[f.field];
      if (value is String) {
        data[f.field] = await _put(record, f.field, base64Decode(value));
      }
    }
    if (record.entity == pageEntity && data['path'] is String) {
      final bytes = (await files.read(data['path']! as String)).valueOrNull;
      if (bytes != null) {
        data['file'] = await _put(record, 'file', bytes);
      }
    }
    return record.copyWithData(data, updatedAt: record.updatedAt, deviceId: record.deviceId);
  }

  Future<SyncRecord> internalize(SyncRecord record) async {
    if (record.isDeleted) {
      return record;
    }
    final Map<String, Object?> data = <String, Object?>{...record.data};
    for (final BlobField f in inlineFields.where((f) => f.entity == record.entity)) {
      final Object? value = data[f.field];
      if (value is Map<String, Object?>) {
        data[f.field] = base64Encode(await _get(value));
      }
    }
    final Object? file = data.remove('file');
    if (record.entity == pageEntity && file is Map<String, Object?> && data['path'] is String) {
      final Uint8List bytes = await _get(file);
      final result = await files.write(data['path']! as String, bytes);
      if (result.isFailure) {
        throw FileSystemException('Не удалось сохранить файл страницы', data['path']! as String);
      }
    }
    return record.copyWithData(data, updatedAt: record.updatedAt, deviceId: record.deviceId);
  }

  Future<Map<String, Object?>> _put(SyncRecord r, String field, Uint8List bytes) async {
    final String hash = sha256.convert(bytes).toString();
    final String path = '${blobs.userId}/${r.entity}/${Uri.encodeComponent(r.syncId)}/$field-$hash.gz';
    if (!await blobs.exists(path)) {
      await blobs.upload(path, Uint8List.fromList(gzip.encode(bytes)));
    }
    return <String, Object?>{'blob': path, 'sha256': hash, 'size': bytes.length};
  }

  Future<Uint8List> _get(Map<String, Object?> ref) async {
    final Uint8List packed = await blobs.download(ref['blob']! as String);
    final Uint8List bytes = Uint8List.fromList(gzip.decode(packed));
    if (sha256.convert(bytes).toString() != ref['sha256']) {
      throw FileSystemException('Контрольная сумма файла не сошлась', ref['blob']! as String);
    }
    return bytes;
  }
}
