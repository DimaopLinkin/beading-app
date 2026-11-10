import 'dart:typed_data';

import 'package:beading/core/result.dart';

/// Файлы приложения в Application Support. Все пути относительные: абсолютный путь меняется при переустановке.
abstract interface class FileStore {
  /// Содержимое файла. Нет файла — [StorageFailure](../../core/failure.dart).
  Future<Result<Uint8List>> read(String relativePath);

  Future<Result<void>> write(String relativePath, Uint8List bytes);

  Future<Result<void>> copy({required String from, required String to});

  /// Удаляет файл; отсутствующий файл — не ошибка.
  Future<Result<void>> delete(String relativePath);
}
