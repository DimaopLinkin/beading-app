import 'package:beading/presentation/dev/frame_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FrameStats stats() => FrameStats(capacity: 5);

  test('пустая статистика — нули', () {
    final FrameStats s = stats();

    expect(s.frames, 0);
    expect(s.averageMs, 0);
    expect(s.p95Ms, 0);
    expect(s.worstMs, 0);
    expect(s.countOver(8.3), 0);
  });

  test('кадр = сборка + растеризация', () {
    final FrameStats s = stats()..add(build: const Duration(milliseconds: 3), raster: const Duration(milliseconds: 5));

    expect(s.frames, 1);
    expect(s.averageMs, 8);
    expect(s.worstMs, 8);
  });

  test('среднее, худший и превышения бюджета', () {
    final FrameStats s = stats();
    for (final int ms in <int>[4, 6, 8, 10, 20]) {
      s.add(
        build: Duration(milliseconds: ms),
        raster: Duration.zero,
      );
    }

    expect(s.averageMs, 9.6);
    expect(s.worstMs, 20);
    expect(s.countOver(8.33), 2);
    expect(s.countOver(16.67), 1);
  });

  test('p95 — значение, ниже которого 95% кадров', () {
    final FrameStats s = FrameStats(capacity: 100);
    for (var i = 1; i <= 100; i++) {
      s.add(
        build: Duration(milliseconds: i),
        raster: Duration.zero,
      );
    }

    expect(s.p95Ms, 95);
  });

  test('хранит только последние capacity кадров, но считает все', () {
    final FrameStats s = stats();
    for (var i = 1; i <= 8; i++) {
      s.add(
        build: Duration(milliseconds: i),
        raster: Duration.zero,
      );
    }

    expect(s.frames, 8);
    expect(s.worstMs, 8);
    expect(s.countOver(0), 5, reason: 'в окне 5 кадров: 4…8');
  });

  test('reset обнуляет', () {
    final FrameStats s = stats()..add(build: const Duration(milliseconds: 3), raster: Duration.zero);

    s.reset();

    expect(s.frames, 0);
    expect(s.worstMs, 0);
  });

  test('capacity должен быть положительным', () {
    expect(() => FrameStats(capacity: 0), throwsA(isA<AssertionError>()));
  });
}
