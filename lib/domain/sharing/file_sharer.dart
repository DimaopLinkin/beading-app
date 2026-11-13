import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:beading/domain/sharing/text_sharer.dart';

/// Отдаёт файл системному листу «Поделиться» (AirDrop, «Сохранить в Файлы», почта).
abstract interface class FileSharer {
  /// Ошибка платформы приходит как `UnexpectedFailure`; закрытый пользователем лист — успех.
  Future<Result<void>> shareFile({required Uint8List bytes, required String fileName, ShareOrigin? origin});
}
