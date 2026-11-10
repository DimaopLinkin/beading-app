import 'dart:typed_data';

/// Растровая картинка для превращения в схему: пиксели RGBA по 8 бит, ряды сверху вниз, слева направо.
///
/// Декодирование файла — забота слоя data: домен получает уже готовые пиксели.
final class SourceImage {
  SourceImage({required this.width, required this.height, required this.rgba}) {
    if (width < 1) throw ArgumentError.value(width, 'width', 'не меньше 1');
    if (height < 1) throw ArgumentError.value(height, 'height', 'не меньше 1');
    if (rgba.length != width * height * 4) {
      throw ArgumentError.value(rgba.length, 'rgba', 'ожидалось ${width * height * 4} байт');
    }
  }

  /// Картинка одного цвета: удобно в тестах и для заливки фона.
  factory SourceImage.solid({required int width, required int height, required int r, required int g, required int b}) {
    final Uint8List bytes = Uint8List(width * height * 4);
    for (int i = 0; i < bytes.length; i += 4) {
      bytes[i] = r;
      bytes[i + 1] = g;
      bytes[i + 2] = b;
      bytes[i + 3] = 255;
    }
    return SourceImage(width: width, height: height, rgba: bytes);
  }

  final int width;
  final int height;
  final Uint8List rgba;
}
