import 'dart:typed_data';
import 'dart:ui' as ui;

/// PNG 4×2: левая половина красная, правая синяя.
Future<Uint8List> redBluePng({int width = 4, int height = 2}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawRect(ui.Rect.fromLTWH(0, 0, width / 2, height.toDouble()), ui.Paint()..color = const ui.Color(0xFFFF0000))
    ..drawRect(
      ui.Rect.fromLTWH(width / 2, 0, width / 2, height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF0000FF),
    );
  final ui.Image image = await recorder.endRecording().toImage(width, height);
  final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  return data.buffer.asUint8List();
}

/// Размер и пиксели PNG: цвет в формате 0xAARRGGBB по строкам.
Future<({int width, int height, List<int> pixels})> decodePng(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.Image image = (await codec.getNextFrame()).image;
  final ByteData rgba = (await image.toByteData())!;
  final List<int> pixels = <int>[
    for (int i = 0; i < image.width * image.height; i++)
      (rgba.getUint8(i * 4 + 3) << 24) | (rgba.getUint8(i * 4) << 16) | (rgba.getUint8(i * 4 + 1) << 8) | rgba.getUint8(i * 4 + 2),
  ];
  final result = (width: image.width, height: image.height, pixels: pixels);
  image.dispose();
  codec.dispose();
  return result;
}
