import 'dart:io';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:path/path.dart' as p;

/// Файлы приложения в каталоге [root] (в приложении — Application Support).
/// Пути только относительные и не выходят за [root].
class LocalFileStore implements FileStore {
  const LocalFileStore(this.root);

  final Directory root;

  @override
  Future<Result<void>> write(String relativePath, Uint8List bytes) => _guard(() async {
    final File target = _resolve(relativePath);
    await target.parent.create(recursive: true);
    // Сначала во временный файл: оборванная запись не оставит битую страницу под настоящим именем.
    final File temp = File('${target.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(target.path);
  });

  @override
  Future<Result<void>> copy({required String from, required String to}) => _guard(() async {
    final File source = _resolve(from);
    final File target = _resolve(to);
    await target.parent.create(recursive: true);
    await source.copy(target.path);
  });

  @override
  Future<Result<void>> delete(String relativePath) => _guard(() async {
    final File target = _resolve(relativePath);
    if (target.existsSync()) {
      await target.delete();
    }
    // Пустой каталог схемы убираем вместе с последним файлом.
    final Directory parent = target.parent;
    if (p.isWithin(root.path, parent.path) && parent.existsSync() && parent.listSync().isEmpty) {
      await parent.delete();
    }
  });

  File _resolve(String relativePath) {
    if (p.isAbsolute(relativePath)) {
      throw ArgumentError.value(relativePath, 'relativePath', 'Нужен относительный путь');
    }
    final String full = p.normalize(p.join(root.path, relativePath));
    if (!p.isWithin(root.path, full)) {
      throw ArgumentError.value(relativePath, 'relativePath', 'Путь выходит за каталог приложения');
    }
    return File(full);
  }

  Future<Result<void>> _guard(Future<void> Function() action) async {
    try {
      await action();
      return const Success<void>(null);
    } on FileSystemException catch (error) {
      return Err<void>(StorageFailure('${error.message}: ${error.path}'));
    } on ArgumentError catch (error) {
      return Err<void>(ValidationFailure('${error.message}'));
    }
  }
}
