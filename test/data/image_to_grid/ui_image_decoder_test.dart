import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beading/core/result.dart';
import 'package:beading/data/image_to_grid/ui_image_decoder.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_images.dart';

Future<Result<SourceImage>> _decode(Uint8List Function() bytes, {int maxSide = 1024}) =>
    const UiImageDecoder().decode(bytes(), maxSide: maxSide);

void main() {
  testWidgets('отдаёт пиксели RGBA: левая половина красная, правая синяя', (tester) async {
    final Result<SourceImage>? result = await tester.runAsync(() async {
      final Uint8List png = await redBluePng();
      return _decode(() => png);
    });
    final SourceImage image = result!.valueOrNull!;
    expect((image.width, image.height), (4, 2));
    expect(image.rgba.sublist(0, 4), <int>[255, 0, 0, 255]);
    expect(image.rgba.sublist(12, 16), <int>[0, 0, 255, 255]);
  });

  testWidgets('полупрозрачный пиксель сохраняет свой цвет: красный остаётся красным, а не темнеет', (tester) async {
    final Result<SourceImage>? result = await tester.runAsync(() async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 2, 2),
        ui.Paint()
          ..color = const ui.Color(0x80FF0000)
          ..blendMode = ui.BlendMode.src,
      );
      final ui.Image drawn = await recorder.endRecording().toImage(2, 2);
      final ByteData png = (await drawn.toByteData(format: ui.ImageByteFormat.png))!;
      drawn.dispose();
      return _decode(png.buffer.asUint8List);
    });
    final SourceImage image = result!.valueOrNull!;
    expect(image.rgba[3], closeTo(128, 1));
    expect(image.rgba[0], greaterThan(250));
    expect(image.rgba.sublist(1, 3), <int>[0, 0]);
  });

  testWidgets('уменьшает длинную сторону до maxSide', (tester) async {
    final Result<SourceImage>? result = await tester.runAsync(() async {
      final Uint8List png = await redBluePng(width: 40, height: 20);
      return _decode(() => png, maxSide: 10);
    });
    final SourceImage image = result!.valueOrNull!;
    expect((image.width, image.height), (10, 5));
  });

  testWidgets('битые байты — ошибка, а не исключение', (tester) async {
    final Result<SourceImage>? result = await tester.runAsync(() => _decode(() => Uint8List.fromList(<int>[1, 2, 3])));
    expect(result, isA<Err<SourceImage>>());
  });
}
