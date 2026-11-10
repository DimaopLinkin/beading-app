import 'dart:typed_data';

import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:flutter_test/flutter_test.dart';

import '../grid/fake_cell_metrics.dart';
import 'image_fixtures.dart';

WorkImage work(SourceImage image, {int columns = 2, int rows = 2, Float32List? importance, GridGeometry? geometry}) =>
    WorkImage.fromSource(
      image: image,
      geometry: geometry ?? const GridGeometry.rectangular(),
      metrics: const FakeCellMetrics(1, 1),
      columns: columns,
      rows: rows,
      importance: importance,
    );

void main() {
  group('WorkImage.fromSource', () {
    test('размер — по ячейкам и масштабу: 6 пикселей на ячейку у мелкой схемы', () {
      final WorkImage image = work(
        blockImage(<List<int>>[
          <int>[0xFF0000],
        ], block: 40),
        columns: 4,
        rows: 3,
      );
      expect(image.width, 24);
      expect(image.height, 18);
    });

    test('масштаб падает с размером схемы', () {
      expect(WorkImage.scaleFor(columns: 50, rows: 50), 6);
      expect(WorkImage.scaleFor(columns: 100, rows: 100), 5);
      expect(WorkImage.scaleFor(columns: 150, rows: 200), 4);
      expect(WorkImage.scaleFor(columns: 300, rows: 300), 3);
    });

    test('пейот: высота рабочей картинки учитывает сдвиг рядов', () {
      final WorkImage image = work(
        blockImage(<List<int>>[
          <int>[0xFF0000],
        ], block: 40),
        columns: 4,
        rows: 4,
        geometry: const GridGeometry.peyote(),
      );
      expect(image.width, 24);
      expect(image.height, isNot(24));
    });

    test('смесь чёрного и белого 50/50 в линейном свете даёт sRGB около 188, а не 128', () {
      // Столбцы чередуются: каждый рабочий пиксель (два столбца исходника) — смесь поровну.
      final SourceImage stripes = blockImage(<List<int>>[
        <int>[for (int x = 0; x < 12; x++) x.isEven ? 0x000000 : 0xFFFFFF],
      ]);
      final WorkImage image = work(stripes, columns: 1, rows: 1);
      final SourceImage back = image.toSourceImage();
      expect(image.width, 6);
      for (int i = 0; i < image.width * image.height; i++) {
        expect(back.rgba[i * 4], closeTo(188, 2));
      }
    });

    test('прозрачность и маска важности переходят в рабочее разрешение', () {
      final Uint8List rgba = Uint8List(4 * 4 * 4);
      for (int i = 0; i < 16; i++) {
        rgba[i * 4] = 200;
        rgba[i * 4 + 3] = i % 4 < 2 ? 255 : 0;
      }
      final Float32List mask = Float32List(16)..fillRange(0, 16, 3);
      final WorkImage image = work(SourceImage(width: 4, height: 4, rgba: rgba), columns: 1, rows: 1, importance: mask);
      expect(image.alpha.first, 1);
      expect(image.alpha.last, 0);
      expect(image.importance.every((w) => (w - 3).abs() < 1e-5), isTrue);
    });

    test('маска не того размера — ошибка', () {
      expect(
        () => work(SourceImage.solid(width: 2, height: 2, r: 0, g: 0, b: 0), importance: Float32List(3)),
        throwsArgumentError,
      );
    });

    test('сетка меньше 1×1 — ошибка', () {
      expect(() => work(SourceImage.solid(width: 2, height: 2, r: 0, g: 0, b: 0), columns: 0), throwsArgumentError);
    });

    test('конструктор проверяет размеры массивов', () {
      expect(
        () => WorkImage(
          width: 2,
          height: 2,
          lightness: Float32List(3),
          a: Float32List(4),
          b: Float32List(4),
          alpha: Float32List(4),
          importance: Float32List(4),
        ),
        throwsArgumentError,
      );
      expect(
        () => WorkImage(
          width: 0,
          height: 1,
          lightness: Float32List(0),
          a: Float32List(0),
          b: Float32List(0),
          alpha: Float32List(0),
          importance: Float32List(0),
        ),
        throwsArgumentError,
      );
      expect(
        () => WorkImage(
          width: 1,
          height: 0,
          lightness: Float32List(0),
          a: Float32List(0),
          b: Float32List(0),
          alpha: Float32List(0),
          importance: Float32List(0),
        ),
        throwsArgumentError,
      );
    });

    test('исходник меньше рабочей картинки растягивается без пустот', () {
      final WorkImage image = work(
        blockImage(<List<int>>[
          <int>[0x336699],
        ]),
        columns: 3,
        rows: 3,
      );
      expect(image.width, 18);
      final SourceImage back = image.toSourceImage();
      for (int i = 0; i < image.width * image.height; i++) {
        expect(back.rgba[i * 4 + 3], 255);
        expect((back.rgba[i * 4] - 0x33).abs(), lessThanOrEqualTo(1));
      }
    });
  });
}
