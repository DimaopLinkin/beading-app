import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';

/// Маски и лица на фото: что на картинке главное (ADR-0004, маска важности; T48).
///
/// Реализация лежит в слое data (Apple Vision через платформенный канал). Домен и тесты работают с фейком.
/// Ошибка или `MissingPluginException` не должны ломать мастер: вызывающий при [Err] просто строит схему без масок.
abstract interface class ImageMasks {
  /// Анализирует картинку [image] (закодированный PNG или JPEG).
  ///
  /// Все маски результата имеют размер ровно [width] × [height]: это размер [SourceImage] конвейера, платформа
  /// сама приводит маски к нему. Ряды сверху вниз, слева направо.
  Future<Result<ImageMaskSet>> analyze(Uint8List image, {required int width, required int height});
}
