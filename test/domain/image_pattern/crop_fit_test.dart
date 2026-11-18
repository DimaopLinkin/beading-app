import 'package:beading/domain/image_pattern/crop_fit.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const double imageAspect = 1.5; // 3:2
  const CropRect user = CropRect(left: 0.2, top: 0.2, right: 0.6, bottom: 0.7);

  double physicalAspect(CropRect c) => c.width * imageAspect / c.height;

  void expectInside(CropRect c) {
    expect(c.left, greaterThanOrEqualTo(0));
    expect(c.top, greaterThanOrEqualTo(0));
    expect(c.right, lessThanOrEqualTo(1 + 1e-12));
    expect(c.bottom, lessThanOrEqualTo(1 + 1e-12));
  }

  void expectSame(CropRect a, CropRect b) {
    expect(a.left, closeTo(b.left, 1e-9));
    expect(a.top, closeTo(b.top, 1e-9));
    expect(a.right, closeTo(b.right, 1e-9));
    expect(a.bottom, closeTo(b.bottom, 1e-9));
  }

  group('CropFit.fitAspect', () {
    test('даёт нужный физический аспект, центр и площадь сохраняются', () {
      final CropRect r = CropFit.fitAspect(user, imageAspect, 1);
      expect(physicalAspect(r), closeTo(1, 1e-9));
      expect(r.width * r.height, closeTo(user.width * user.height, 1e-9));
      expect((r.left + r.right) / 2, closeTo(0.4, 1e-9));
      expect((r.top + r.bottom) / 2, closeTo(0.45, 1e-9));
      expectInside(r);
    });

    test('идемпотентна', () {
      final CropRect once = CropFit.fitAspect(user, imageAspect, 16 / 9);
      expectSame(CropFit.fitAspect(once, imageAspect, 16 / 9), once);
    });

    test('рамка у края сдвигается внутрь', () {
      const CropRect corner = CropRect(left: 0.6, top: 0.6, right: 1, bottom: 1);
      final CropRect r = CropFit.fitAspect(corner, imageAspect, 4);
      expectInside(r);
      expect(physicalAspect(r), closeTo(4, 1e-9));
    });

    test('не помещающаяся рамка уменьшается до вписанной', () {
      final CropRect r = CropFit.fitAspect(CropRect.full, imageAspect, 3);
      expectInside(r);
      expect(physicalAspect(r), closeTo(3, 1e-9));
      expect(r.width, closeTo(1, 1e-9));
    });

    test('цепочка 1:1 → 16:9 → 1:1 без дрейфа, пока рамка не упёрлась в край', () {
      const CropRect middle = CropRect(left: 0.35, top: 0.35, right: 0.65, bottom: 0.65);
      final CropRect square = CropFit.fitAspect(middle, 1, 1);
      final CropRect wide = CropFit.fitAspect(square, 1, 16 / 9);
      final CropRect back = CropFit.fitAspect(wide, 1, 1);
      expectSame(back, square);
    });

    test('любой аспект и рамка остаются в [0, 1]', () {
      for (final double aspect in <double>[0.2, 0.5, 1, 1.5, 3, 8]) {
        expectInside(CropFit.fitAspect(user, imageAspect, aspect));
      }
    });
  });

  group('CropFit.panLocked / zoomLocked / rotateAspect', () {
    test('сдвиг упирается в край и не меняет размер', () {
      final CropRect r = CropFit.panLocked(user, 5, -5);
      expect(r.width, closeTo(user.width, 1e-12));
      expect(r.height, closeTo(user.height, 1e-12));
      expect(r.right, closeTo(1, 1e-12));
      expect(r.top, closeTo(0, 1e-12));
    });

    test('приближение уменьшает рамку, аспект и центр сохраняются', () {
      final CropRect r = CropFit.zoomLocked(user, 2);
      expect(r.width, closeTo(user.width / 2, 1e-9));
      expect(r.width / r.height, closeTo(user.width / user.height, 1e-9));
      expect((r.left + r.right) / 2, closeTo(0.4, 1e-9));
    });

    test('отдаление ограничено максимальной вписанной рамкой', () {
      final CropRect r = CropFit.zoomLocked(user, 0.01);
      expectInside(r);
      expect(r.height, closeTo(1, 1e-9));
      expect(r.width / r.height, closeTo(user.width / user.height, 1e-9));
    });

    test('поворот аспекта: 3:4 ↔ 4:3', () {
      expect(CropFit.rotateAspect(3 / 4), closeTo(4 / 3, 1e-12));
      expect(CropFit.rotateAspect(CropFit.rotateAspect(0.4)), closeTo(0.4, 1e-12));
    });
  });
}
