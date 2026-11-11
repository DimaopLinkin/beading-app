import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:flutter_test/flutter_test.dart';

/// Лицо в центре картинки 40×40 с глазами и губами.
DetectedFace _face() => const DetectedFace(
  bounds: NormalizedRect(left: 0.3, top: 0.3, right: 0.7, bottom: 0.7),
  landmarks: FaceLandmarks(
    leftEye: <NormalizedPoint>[
      NormalizedPoint(0.35, 0.4),
      NormalizedPoint(0.45, 0.4),
      NormalizedPoint(0.45, 0.45),
      NormalizedPoint(0.35, 0.45),
    ],
    rightPupil: <NormalizedPoint>[NormalizedPoint(0.6, 0.425)],
    outerLips: <NormalizedPoint>[NormalizedPoint(0.4, 0.6), NormalizedPoint(0.6, 0.6)],
  ),
);

void main() {
  test('размер маски обязан совпадать с картинкой', () {
    expect(() => ImageMaskSet(width: 4, height: 4, subject: Uint8List(15)), throwsArgumentError);
    expect(() => ImageMaskSet(width: 0, height: 4), throwsArgumentError);
  });

  test('без масок и лиц маски важности нет', () {
    final ImageMaskSet set = ImageMaskSet.empty(width: 4, height: 4);
    expect(set.isEmpty, isTrue);
    expect(set.importance(), isNull);
  });

  test('веса: лицо ×4, объект ×2, фон ×0,5', () {
    final Uint8List subject = Uint8List(40 * 40);
    for (int y = 10; y < 30; y++) {
      for (int x = 0; x < 40; x++) {
        subject[y * 40 + x] = 255;
      }
    }
    final ImageMaskSet set = ImageMaskSet(width: 40, height: 40, subject: subject, faces: <DetectedFace>[_face()]);
    final Float32List w = set.importance()!;
    expect(w[20 * 40 + 20], 4); // лицо
    expect(w[12 * 40 + 2], 2); // объект вне лица
    expect(w[2 * 40 + 2], 0.5); // фон
  });

  test('маска важности на фикстуре с лицом покрывает глаза и зрачки полным весом лица', () {
    final ImageMaskSet set = ImageMaskSet(width: 40, height: 40, faces: <DetectedFace>[_face()]);
    final Float32List w = set.importance()!;
    final Uint8List features = set.featureMask();
    expect(features.where((v) => v != 0), isNotEmpty);
    for (int i = 0; i < features.length; i++) {
      if (features[i] != 0) expect(w[i], 4, reason: 'пиксель $i — черта лица');
    }
    expect(features[(0.425 * 40).floor() * 40 + (0.4 * 40).floor() + 2], isNot(0), reason: 'внутри левого глаза');
    expect(features[(0.425 * 40).floor() * 40 + (0.6 * 40).floor()], isNot(0), reason: 'зрачок — одна точка');
    expect(features[0], 0);
  });

  test('без лиц и объекта маска важности идёт по значимости', () {
    final Uint8List saliency = Uint8List(16)..[5] = 255;
    final Float32List w = ImageMaskSet(width: 4, height: 4, saliency: saliency).importance()!;
    expect(w[5], 2);
    expect(w[0], 0.5);
  });

  test('значимость не подмешивается, когда есть объект', () {
    final Uint8List subject = Uint8List(16)..[0] = 1;
    final Uint8List saliency = Uint8List(16)..fillRange(0, 16, 255);
    final Float32List w = ImageMaskSet(width: 4, height: 4, subject: subject, saliency: saliency).importance()!;
    expect(w[0], 2);
    expect(w[1], 0.5);
  });

  test('маска человека заменяет объект, если объекта нет', () {
    final Uint8List person = Uint8List(16)..[3] = 200;
    final ImageMaskSet set = ImageMaskSet(width: 4, height: 4, person: person);
    expect(set.subjectOrPerson, person);
    expect(set.importance()![3], 2);
  });

  test('лицо у края картинки не выходит за её границы', () {
    const DetectedFace edge = DetectedFace(bounds: NormalizedRect(left: 0.9, top: 0.9, right: 1, bottom: 1));
    final Float32List w = ImageMaskSet(width: 10, height: 10, faces: const <DetectedFace>[edge]).importance()!;
    expect(w[99], 4);
  });
}
