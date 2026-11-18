import 'dart:math' as math;

import 'package:beading/domain/image_pattern/crop_rect.dart';

/// Подгонка рамки обрезки под нужные пропорции (T88a). Чистые функции, всё в долях изображения.
///
/// Рамка хранится в долях ширины и высоты картинки, поэтому физический аспект рамки в пикселях —
/// `width * imageAspect / height`, где `imageAspect` — ширина / высота пикселей повёрнутой картинки.
abstract final class CropFit {
  /// Самая маленькая сторона рамки при приближении, доля изображения.
  static const double minSide = 0.02;

  /// Рамка аспекта [targetAspect] (ширина / высота) с центром в центре [user], площадью примерно как у неё.
  ///
  /// Если рамка не помещается в изображение, она уменьшается, затем сдвигается внутрь `[0, 1]`. Повторный вызов с
  /// тем же аспектом ничего не меняет (идемпотентна); цепочка смен аспекта не дрейфует, пока рамка не упёрлась в край
  /// (площадь сохраняется, а центр сдвигается только при необходимости).
  static CropRect fitAspect(CropRect user, double imageAspect, double targetAspect) {
    _check(imageAspect, 'imageAspect');
    _check(targetAspect, 'targetAspect');
    final double ratio = targetAspect / imageAspect; // ширина / высота в долях
    final double area = user.width * user.height;
    double height = math.sqrt(area / ratio);
    double width = height * ratio;
    if (width > 1) {
      width = 1;
      height = 1 / ratio;
    }
    if (height > 1) {
      height = 1;
      width = ratio;
    }
    final double cx = (user.left + user.right) / 2;
    final double cy = (user.top + user.bottom) / 2;
    return _placed(cx, cy, width, height);
  }

  /// Рамка, сдвинутая на ([dx], [dy]) долей изображения при зафиксированном размере: двигается только фото под
  /// рамкой. Сдвиг упирается в край изображения.
  static CropRect panLocked(CropRect crop, double dx, double dy) {
    final double left = (crop.left + dx).clamp(0.0, 1 - crop.width);
    final double top = (crop.top + dy).clamp(0.0, 1 - crop.height);
    return CropRect(left: left, top: top, right: left + crop.width, bottom: top + crop.height);
  }

  /// Масштаб фото под зафиксированной по аспекту рамкой: [scale] больше 1 приближает (рамка меньше), меньше 1
  /// отдаляет. Центр сохраняется. Отдаление ограничено максимальной вписанной рамкой того же аспекта, приближение —
  /// [minSide].
  static CropRect zoomLocked(CropRect crop, double scale) {
    if (!scale.isFinite || scale <= 0) throw ArgumentError.value(scale, 'scale', 'положительное число');
    final double lowest = math.max(crop.width, crop.height); // при таком масштабе рамка упирается в край
    final double highest = math.max(lowest, math.min(crop.width, crop.height) / minSide);
    final double factor = scale.clamp(lowest, highest);
    return _placed(
      (crop.left + crop.right) / 2,
      (crop.top + crop.bottom) / 2,
      crop.width / factor,
      crop.height / factor,
    );
  }

  /// Тот же формат, повёрнутый на 90°: 3:4 ↔ 4:3.
  static double rotateAspect(double aspect) {
    _check(aspect, 'aspect');
    return 1 / aspect;
  }

  static CropRect _placed(double cx, double cy, double width, double height) {
    final double w = width.clamp(minSide / 10, 1.0);
    final double h = height.clamp(minSide / 10, 1.0);
    final double left = (cx - w / 2).clamp(0.0, 1 - w);
    final double top = (cy - h / 2).clamp(0.0, 1 - h);
    return CropRect(left: left, top: top, right: left + w, bottom: top + h);
  }

  static void _check(double value, String name) {
    if (!value.isFinite || value <= 0) throw ArgumentError.value(value, name, 'положительное число');
  }
}
