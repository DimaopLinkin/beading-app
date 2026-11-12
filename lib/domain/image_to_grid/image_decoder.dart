import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';

/// Длинная сторона картинки в мастере «картинка → схема», пикселей: столько отдаёт обработчик и столько декодируется.
const int wizardImageMaxSide = 2048;

/// Превращает файл картинки (PNG, JPEG, HEIC…) в пиксели для конвейера. Реализация лежит в слое data.
abstract interface class ImageDecoder {
  /// Длинная сторона результата не больше [maxSide]: для схемы в сотню клеток большая картинка не нужна,
  /// а расчёт на ней тормозит предпросмотр.
  Future<Result<SourceImage>> decode(Uint8List bytes, {int maxSide = 1024});
}
