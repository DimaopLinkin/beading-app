import 'package:beading/core/result.dart';
import 'package:beading/data/platform/method_channel_image_masks.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(MethodChannelImageMasks.name);
  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final MethodChannelImageMasks masks = MethodChannelImageMasks();
  final Uint8List png = Uint8List.fromList(<int>[1, 2, 3]);

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('канал называется app.beading/image_masks', () {
    expect(MethodChannelImageMasks.name, 'app.beading/image_masks');
  });

  test('отправляет картинку и размер масок, разбирает ответ платформы', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return <String, Object?>{
        'subject': Uint8List(8),
        'saliency': Uint8List(7), // не тот размер: отбрасывается
        'faces': <Object?>[
          <String, Object?>{
            'bounds': <double>[0.1, 0.2, 0.5, 0.6],
            'landmarks': <String, Object?>{
              'leftEye': <double>[0.2, 0.3, 0.3, 0.3],
              'nose': <double>[0.3, 0.4, 0.3],
            },
          },
          <String, Object?>{'bounds': 'мусор'},
        ],
      };
    });

    final Result<ImageMaskSet> result = await masks.analyze(png, width: 4, height: 2);

    expect(received!.method, 'analyze');
    expect(received!.arguments, <String, Object?>{'image': png, 'width': 4, 'height': 2});
    final ImageMaskSet set = result.valueOrNull!;
    expect(set.subject, hasLength(8));
    expect(set.saliency, isNull);
    expect(set.faces, hasLength(1));
    expect(set.faces.single.bounds, const NormalizedRect(left: 0.1, top: 0.2, right: 0.5, bottom: 0.6));
    expect(set.faces.single.landmarks.leftEye, const <NormalizedPoint>[
      NormalizedPoint(0.2, 0.3),
      NormalizedPoint(0.3, 0.3),
    ]);
    expect(set.faces.single.landmarks.nose, const <NormalizedPoint>[
      NormalizedPoint(0.3, 0.4),
    ], reason: 'нечётный хвост отброшен');
  });

  test('пустой ответ — набор без масок', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    final ImageMaskSet set = (await masks.analyze(png, width: 4, height: 2)).valueOrNull!;
    expect(set.isEmpty, isTrue);
  });

  test('без нативной части — Err, без исключения', () async {
    expect(await masks.analyze(png, width: 4, height: 2), isA<Err<ImageMaskSet>>());
  });

  test('ошибка платформы — Err', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'analysis_failed'),
    );
    expect(await masks.analyze(png, width: 4, height: 2), isA<Err<ImageMaskSet>>());
  });

  test('маска неверной длины и лицо с битой рамкой отбрасываются', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => <String, Object?>{
        'person': Uint8List(3),
        'faces': <Object?>[
          <String, Object?>{
            'bounds': <double>[0, 0, 1],
          },
        ],
      },
    );
    final ImageMaskSet set = (await masks.analyze(png, width: 4, height: 2)).valueOrNull!;
    expect(set.person, isNull);
    expect(set.faces, isEmpty);
  });
}
