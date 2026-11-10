import 'dart:typed_data';

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
