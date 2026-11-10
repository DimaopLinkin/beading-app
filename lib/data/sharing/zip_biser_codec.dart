import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/sharing/biser/biser_codec.dart';
import 'package:beading/domain/sharing/biser/biser_json.dart';
import 'package:beading/domain/sharing/biser/biser_models.dart';

/// `.biser` — обычный zip: `manifest.json` и картинки страниц в `images/`.
class ZipBiserCodec implements BiserCodec {
  const ZipBiserCodec();

  /// Предел распакованного размера: защита от «бомбы» в чужом файле.
  static const int maxUnpackedBytes = 512 * 1024 * 1024;

  /// Предел числа записей в архиве.
  static const int maxEntries = 5000;

  @override
  Result<Uint8List> encode(BiserBundle bundle) {
    try {
      final Archive archive = Archive();
      final List<int> manifest = utf8.encode(BiserJson.encode(bundle));
      archive.addFile(ArchiveFile(BiserJson.manifestPath, manifest.length, manifest));
      for (final MapEntry<String, Uint8List> file in bundle.files.entries) {
        // PNG уже сжат: повторно не жмём.
        archive.addFile(ArchiveFile(file.key, file.value.length, file.value)..compression = CompressionType.none);
      }
      final List<int> bytes = ZipEncoder().encode(archive);
      return Success<Uint8List>(Uint8List.fromList(bytes));
    } on Object catch (error) {
      return Err<Uint8List>(UnexpectedFailure('Не удалось упаковать файл: $error'));
    }
  }

  @override
  Result<BiserBundle> decode(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object {
      return const Err<BiserBundle>(ValidationFailure('Файл повреждён или это не файл «Бисера»'));
    }
    if (archive.files.length > maxEntries) {
      return const Err<BiserBundle>(ValidationFailure('В файле слишком много записей'));
    }
    int total = 0;
    for (final ArchiveFile file in archive.files) {
      total += file.size;
      if (total > maxUnpackedBytes) {
        return const Err<BiserBundle>(ValidationFailure('Файл слишком большой'));
      }
    }
    final Map<String, Uint8List> files = <String, Uint8List>{};
    String? manifest;
    int unpacked = 0;
    try {
      for (final ArchiveFile file in archive.files.where((f) => f.isFile)) {
        final Uint8List content = Uint8List.fromList(file.content as List<int>);
        // Размер в заголовке zip можно подделать: считаем то, что реально распаковали.
        unpacked += content.length;
        if (unpacked > maxUnpackedBytes) {
          return const Err<BiserBundle>(ValidationFailure('Файл слишком большой'));
        }
        if (file.name == BiserJson.manifestPath) {
          manifest = utf8.decode(content);
        } else {
          files[file.name] = content;
        }
      }
    } on Object {
      return const Err<BiserBundle>(ValidationFailure('Файл повреждён: не удалось распаковать'));
    }
    if (manifest == null) {
      return const Err<BiserBundle>(ValidationFailure('Это не файл «Бисера»: нет манифеста'));
    }
    return BiserJson.decode(manifest, files);
  }
}
