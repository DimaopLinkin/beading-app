import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/image_pattern/ui_image_processor.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_pattern/image_processor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_images.dart';

const int _red = 0xFFFF0000;
const int _blue = 0xFF0000FF;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const UiImageProcessor processor = UiImageProcessor();

  Future<({int width, int height, List<int> pixels})> run(
    Uint8List source, {
    int turns = 0,
    CropRect crop = CropRect.full,
    UiImageProcessor p = processor,
  }) async {
    final Result<ProcessedImage> result = await p.process(source, quarterTurns: turns, crop: crop);
    final ProcessedImage image = result.valueOrNull!;
    final decoded = await decodePng(image.png);
    expect((image.width, image.height), (decoded.width, decoded.height));
    return decoded;
  }

  test('без правок отдаёт PNG того же размера и цвета', () async {
    final decoded = await run(await redBluePng());

    expect((decoded.width, decoded.height), (4, 2));
    expect(decoded.pixels, <int>[_red, _red, _blue, _blue, _red, _red, _blue, _blue]);
  });

  test('поворот на 90° по часовой: левая красная половина уходит наверх', () async {
    final decoded = await run(await redBluePng(), turns: 1);

    expect((decoded.width, decoded.height), (2, 4));
    expect(decoded.pixels, <int>[_red, _red, _red, _red, _blue, _blue, _blue, _blue]);
  });

  test('поворот на 180°: половины меняются местами', () async {
    final decoded = await run(await redBluePng(), turns: 2);

    expect((decoded.width, decoded.height), (4, 2));
    expect(decoded.pixels, <int>[_blue, _blue, _red, _red, _blue, _blue, _red, _red]);
  });

  test('поворот на 270° и на -90° одинаковы: красная половина уходит вниз', () async {
    final a = await run(await redBluePng(), turns: 3);
    final b = await run(await redBluePng(), turns: -1);

    expect((a.width, a.height), (2, 4));
    expect(a.pixels, <int>[_blue, _blue, _blue, _blue, _red, _red, _red, _red]);
    expect(b.pixels, a.pixels);
  });

  test('четыре четверти — исходная картинка', () async {
    final decoded = await run(await redBluePng(), turns: 4);

    expect(decoded.pixels, <int>[_red, _red, _blue, _blue, _red, _red, _blue, _blue]);
  });

  test('обрезка берёт область после поворота', () async {
    final decoded = await run(
      await redBluePng(),
      crop: const CropRect(left: 0.5, top: 0, right: 1, bottom: 1),
    );
    expect((decoded.width, decoded.height), (2, 2));
    expect(decoded.pixels, everyElement(_blue));

    final rotated = await run(
      await redBluePng(),
      turns: 1,
      crop: const CropRect(left: 0, top: 0.5, right: 1, bottom: 1),
    );
    expect((rotated.width, rotated.height), (2, 2));
    expect(rotated.pixels, everyElement(_blue));
  });

  test('слишком большая картинка уменьшается до maxSide с сохранением пропорций', () async {
    final decoded = await run(await redBluePng(width: 40, height: 20), p: const UiImageProcessor(maxSide: 10));

    expect((decoded.width, decoded.height), (10, 5));
  });

  test('не картинка — Failure, а не исключение', () async {
    final Result<ProcessedImage> result = await processor.process(Uint8List.fromList(<int>[1, 2, 3]));

    expect(result.failureOrNull, isA<ValidationFailure>());
  });
}
