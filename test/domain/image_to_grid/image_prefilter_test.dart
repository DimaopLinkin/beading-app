import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/image_prefilter.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:flutter_test/flutter_test.dart';

/// Рабочая картинка из функции Lab по координатам.
WorkImage build(int width, int height, Lab Function(int x, int y) color) {
  final Float32List l = Float32List(width * height);
  final Float32List a = Float32List(width * height);
  final Float32List b = Float32List(width * height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final Lab c = color(x, y);
      l[y * width + x] = c.l;
      a[y * width + x] = c.a;
      b[y * width + x] = c.b;
    }
  }
  return WorkImage(
    width: width,
    height: height,
    lightness: l,
    a: a,
    b: b,
    alpha: Float32List(width * height)..fillRange(0, width * height, 1),
    importance: Float32List(width * height)..fillRange(0, width * height, 1),
  );
}

Lab at(WorkImage image, int x, int y) {
  final int i = y * image.width + x;
  return Lab(image.lightness[i], image.a[i], image.b[i]);
}

/// Стандартное отклонение цвета от среднего внутри [margin] от краёв.
double spread(WorkImage image, {int margin = 3}) {
  final List<Lab> values = <Lab>[
    for (int y = margin; y < image.height - margin; y++)
      for (int x = margin; x < image.width - margin; x++) at(image, x, y),
  ];
  final double ml = values.fold(0.0, (s, c) => s + c.l) / values.length;
  final double ma = values.fold(0.0, (s, c) => s + c.a) / values.length;
  final double mb = values.fold(0.0, (s, c) => s + c.b) / values.length;
  final double sum = values.fold(
    0.0,
    (s, c) => s + math.pow(c.l - ml, 2) + math.pow(c.a - ma, 2) + math.pow(c.b - mb, 2),
  );
  return math.sqrt(sum / values.length);
}

void main() {
  // Шум ±10 по RGB на сером фоне, в Lab: примерно ±3,5 по светлоте.
  WorkImage noisyGray(int size, {int seed = 1}) {
    final math.Random random = math.Random(seed);
    return build(size, size, (x, y) => Lab(50 + (random.nextDouble() * 2 - 1) * 3.5, 0, 0));
  }

  group('EdgePreservingPrefilter: двусторонний фильтр', () {
    test('шум на однотонной картинке: разброс ΔE меньше 1', () {
      final WorkImage noisy = noisyGray(40);
      expect(spread(noisy), greaterThan(1.5));
      expect(spread(const EdgePreservingPrefilter(saturation: 1).apply(noisy)), lessThan(1));
    });

    test('резкая граница двух цветов остаётся резкой: переход не шире одного пикселя', () {
      final WorkImage edge = build(30, 10, (x, y) => x < 15 ? const Lab(20, 0, 0) : const Lab(80, 10, 10));
      final WorkImage out = const EdgePreservingPrefilter(saturation: 1).apply(edge);
      for (int y = 0; y < 10; y++) {
        expect(at(out, 13, y).l, closeTo(20, 0.5));
        expect(at(out, 14, y).l, closeTo(20, 1));
        expect(at(out, 15, y).l, closeTo(80, 1));
        expect(at(out, 16, y).l, closeTo(80, 0.5));
      }
    });

    test('детерминизм, вход не меняется', () {
      final WorkImage noisy = noisyGray(20);
      final Float32List before = Float32List.fromList(noisy.lightness);
      final WorkImage first = const EdgePreservingPrefilter().apply(noisy);
      final WorkImage second = const EdgePreservingPrefilter().apply(noisy);
      expect(first.lightness, second.lightness);
      expect(noisy.lightness, before);
    });

    test('прозрачность и маска важности переходят без изменений', () {
      final WorkImage image = build(8, 8, (x, y) => const Lab(50, 0, 0));
      image.alpha[3] = 0.25;
      image.importance[5] = 4;
      final WorkImage out = const EdgePreservingPrefilter().apply(image);
      expect(out.alpha[3], 0.25);
      expect(out.importance[5], 4);
      expect(out.width, 8);
      expect(out.height, 8);
    });

    test('картинка меньше окна фильтра не ломается', () {
      final WorkImage tiny = build(1, 1, (x, y) => const Lab(40, 5, 5));
      final WorkImage out = const EdgePreservingPrefilter(saturation: 1).apply(tiny);
      expect(at(out, 0, 0).l, closeTo(40, 1e-4));
    });
  });

  group('EdgePreservingPrefilter: насыщенность', () {
    test('множитель растягивает цветность, светлоту не трогает', () {
      final WorkImage image = build(6, 6, (x, y) => const Lab(60, 20, -10));
      final WorkImage out = const EdgePreservingPrefilter(saturation: 1.1).apply(image);
      expect(at(out, 3, 3).l, closeTo(60, 1e-3));
      expect(at(out, 3, 3).a, closeTo(22, 1e-3));
      expect(at(out, 3, 3).b, closeTo(-11, 1e-3));
    });

    test('значение вне 1..1,1 отвергается', () {
      expect(() => EdgePreservingPrefilter(saturation: 1.5), throwsA(isA<AssertionError>()));
    });
  });

  group('EdgePreservingPrefilter: управляемый фильтр для больших схем', () {
    const EdgePreservingPrefilter guided = EdgePreservingPrefilter(saturation: 1, guidedAbovePixels: 0);

    test('шум на однотонной картинке: разброс ΔE меньше 1', () {
      expect(spread(guided.apply(noisyGray(40))), lessThan(1));
    });

    test('резкая граница остаётся резкой', () {
      final WorkImage edge = build(30, 10, (x, y) => x < 15 ? const Lab(20, 0, 0) : const Lab(80, 10, 10));
      final WorkImage out = guided.apply(edge);
      for (int y = 2; y < 8; y++) {
        expect(at(out, 12, y).l, closeTo(20, 1));
        expect(at(out, 17, y).l, closeTo(80, 1));
        expect((at(out, 14, y).l - 20).abs() + (at(out, 15, y).l - 80).abs(), lessThan(8));
      }
    });

    test('порог по размеру выбирает фильтр: большая картинка проходит управляемым', () {
      const EdgePreservingPrefilter auto = EdgePreservingPrefilter(saturation: 1, guidedAbovePixels: 100);
      expect(spread(auto.apply(noisyGray(20))), lessThan(1));
    });

    test('прямая проверка: ровная картинка не меняется', () {
      final WorkImage flat = build(12, 12, (x, y) => const Lab(55, 3, 4));
      final WorkImage out = guided.apply(flat);
      expect(at(out, 6, 6).l, closeTo(55, 1e-3));
      expect(at(out, 0, 0).a, closeTo(3, 1e-3));
    });
  });
}
