import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/source_image.dart';

/// Картинка из квадратов: `blocks[row][column]` — цвет `0xRRGGBB` блока размером [block] × [block] пикселей.
SourceImage blockImage(List<List<int>> blocks, {int block = 1, int alpha = 255}) {
  final int width = blocks.first.length * block;
  final int height = blocks.length * block;
  final Uint8List bytes = Uint8List(width * height * 4);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int color = blocks[y ~/ block][x ~/ block];
      final int offset = (y * width + x) * 4;
      bytes[offset] = (color >> 16) & 0xFF;
      bytes[offset + 1] = (color >> 8) & 0xFF;
      bytes[offset + 2] = color & 0xFF;
      bytes[offset + 3] = alpha;
    }
  }
  return SourceImage(width: width, height: height, rgba: bytes);
}

/// Горизонтальный градиент от чёрного к белому.
SourceImage grayRamp({required int width, required int height}) {
  final Uint8List bytes = Uint8List(width * height * 4);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int offset = (y * width + x) * 4;
      final int v = (x * 255 / (width - 1)).round();
      bytes[offset] = v;
      bytes[offset + 1] = v;
      bytes[offset + 2] = v;
      bytes[offset + 3] = 255;
    }
  }
  return SourceImage(width: width, height: height, rgba: bytes);
}
