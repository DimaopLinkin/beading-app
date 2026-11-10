import 'dart:typed_data';

import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/cell_sampler.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import '../grid/fake_cell_metrics.dart';
import 'image_fixtures.dart';

void main() {
  const CellSampler sampler = CellSampler();
  const FakeCellMetrics square = FakeCellMetrics(1, 1);
  const GridGeometry rectangular = GridGeometry.rectangular();

  group('CellSampler', () {
    test('ячейка берёт цвет блока картинки под ней', () {
      final SourceImage image = blockImage(<List<int>>[
        <int>[0xFF0000, 0x00FF00],
        <int>[0x0000FF, 0xFFFFFF],
      ], block: 5);

      final SampledCells cells = sampler.sample(
        image: image,
        geometry: rectangular,
        metrics: square,
        columns: 2,
        rows: 2,
      );

      expect(cells.colors, <Rgb?>[
        const Rgb(255, 0, 0),
        const Rgb(0, 255, 0),
        const Rgb(0, 0, 255),
        const Rgb(255, 255, 255),
      ]);
    });

    test('ячейка на границе двух цветов усредняет их по площади', () {
      // Ширина 4 px под одну ячейку: слева чёрное, справа белое.
      final SourceImage image = blockImage(<List<int>>[
        <int>[0x000000, 0xFFFFFF],
      ], block: 2);

      final SampledCells cells = sampler.sample(
        image: image,
        geometry: rectangular,
        metrics: square,
        columns: 1,
        rows: 1,
      );

      expect(cells.colors.single, const Rgb(128, 128, 128));
    });

    test('доля пикселя считается дробной: ячейка в 1,5 пикселя', () {
      // 3 px → 2 ячейки: центральный пиксель делится пополам между ячейками.
      final SourceImage image = blockImage(<List<int>>[
        <int>[0xFF0000, 0x00FF00, 0x0000FF],
      ]);

      final SampledCells cells = sampler.sample(
        image: image,
        geometry: rectangular,
        metrics: square,
        columns: 2,
        rows: 1,
      );

      // Левая: 1 красный + 0,5 зелёного → (170, 85, 0).
      expect(cells.colors[0], const Rgb(170, 85, 0));
      expect(cells.colors[1], const Rgb(0, 85, 170));
    });

    test('прозрачные пиксели не подмешиваются в цвет, а прозрачная ячейка пуста', () {
      final SourceImage opaqueRed = blockImage(<List<int>>[
        <int>[0xFF0000],
      ], block: 2);
      final Uint8List bytes = Uint8List.fromList(opaqueRed.rgba);
      for (int i = 3; i < bytes.length; i += 8) {
        bytes[i] = 0; // каждый второй пиксель прозрачен
      }
      final SourceImage halfTransparent = SourceImage(width: 2, height: 2, rgba: bytes);
      final SourceImage fullyTransparent = blockImage(<List<int>>[
        <int>[0x00FF00],
      ], alpha: 0);

      expect(
        sampler.sample(image: halfTransparent, geometry: rectangular, metrics: square, columns: 1, rows: 1).colors,
        <Rgb?>[const Rgb(255, 0, 0)],
      );
      expect(
        sampler.sample(image: fullyTransparent, geometry: rectangular, metrics: square, columns: 1, rows: 1).colors,
        <Rgb?>[null],
      );
    });

    test('вес ячейки — среднее маски под ней: слева 2, справа 0', () {
      final SourceImage image = blockImage(<List<int>>[
        <int>[0xFF0000, 0xFF0000],
      ], block: 2);
      // Картинка 4×2 px; маска по рядам: 2, 2, 0, 0.
      final Float32List mask = Float32List.fromList(<double>[2, 2, 0, 0, 2, 2, 0, 0]);

      final SampledCells cells = sampler.sample(
        image: image,
        geometry: rectangular,
        metrics: square,
        columns: 2,
        rows: 1,
        importance: mask,
      );

      expect(cells.importance, <double>[2, 0]);
    });

    test('без маски вес везде 1', () {
      final SourceImage image = blockImage(<List<int>>[
        <int>[0xFF0000, 0xFF0000],
      ], block: 2);

      final SampledCells cells = sampler.sample(
        image: image,
        geometry: rectangular,
        metrics: square,
        columns: 2,
        rows: 1,
      );

      expect(cells.importance, <double>[1, 1]);
    });

    test('маска неверной длины отклоняется', () {
      final SourceImage image = blockImage(<List<int>>[
        <int>[0xFF0000],
      ]);

      expect(
        () => sampler.sample(
          image: image,
          geometry: rectangular,
          metrics: square,
          columns: 1,
          rows: 1,
          importance: Float32List(3),
        ),
        throwsArgumentError,
      );
    });

    test('пейот: сдвинутые столбцы берут участок картинки ниже на полячейки', () {
      // Картинка 8×20 px: верхние 8 px красные, остальное синее; 2 столбца, 2 ряда.
      // Габариты пейота: 2 × 2,5 ячейки высоты. Столбец 1 сдвинут вниз на 0,5.
      final SourceImage image = blockImage(<List<int>>[
        <int>[0xFF0000, 0xFF0000],
        <int>[0xFF0000, 0xFF0000],
        <int>[0x0000FF, 0x0000FF],
        <int>[0x0000FF, 0x0000FF],
        <int>[0x0000FF, 0x0000FF],
      ], block: 4);

      final SampledCells cells = sampler.sample(
        image: image,
        geometry: const GridGeometry.peyote(),
        metrics: square,
        columns: 2,
        rows: 2,
      );

      expect(
        cells.colors[0],
        const Rgb(255, 0, 0),
      ); // столбец 0, ряд 0: 0..1 ячейки = 0..8 px (картинка 20 px на 2,5 ячейки)
      expect(
        cells.colors[1],
        const Rgb(128, 0, 128),
      ); // столбец 1, ряд 0: 0,5..1,5 ячейки = 4..12 px, красное и синее поровну
    });

    test('картинка меньше сетки: пиксели не выходят за границы', () {
      final SourceImage image = blockImage(<List<int>>[
        <int>[0x336699],
      ]);

      final SampledCells cells = sampler.sample(
        image: image,
        geometry: rectangular,
        metrics: square,
        columns: 5,
        rows: 5,
      );

      expect(cells.colors, everyElement(const Rgb(0x33, 0x66, 0x99)));
    });
  });

  group('GridSizing', () {
    test('квадратные ячейки: пропорции картинки сохраняются', () {
      final int rows = GridSizing.rowsForColumns(
        imageWidth: 200,
        imageHeight: 100,
        geometry: rectangular,
        metrics: square,
        columns: 60,
      );

      expect(rows, 30);
    });

    test('вытянутая бусина: рядов больше, чем столбцов для квадратной картинки', () {
      // Delica 11/0: ширина ячейки 1,3 мм, высота 1,6 мм → на тот же размер нужно больше столбцов, чем рядов.
      final int rows = GridSizing.rowsForColumns(
        imageWidth: 100,
        imageHeight: 100,
        geometry: rectangular,
        metrics: BeadSize.delica11,
        columns: 60,
      );

      expect(rows, 49); // 60 * 1,3 / 1,6 = 48,75
    });

    test('пейот: сдвиг учитывается в габаритах', () {
      final int rows = GridSizing.rowsForColumns(
        imageWidth: 100,
        imageHeight: 100,
        geometry: const GridGeometry.peyote(),
        metrics: square,
        columns: 10,
      );

      // Высота (rows + 0,5) ближе всего к ширине 10 при 9 или 10 рядах: ошибка 5% против 5%, берётся меньшая.
      expect(rows, anyOf(9, 10));
    });

    test('неверные размеры отклоняются', () {
      expect(
        () => GridSizing.rowsForColumns(
          imageWidth: 0,
          imageHeight: 1,
          geometry: rectangular,
          metrics: square,
          columns: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => GridSizing.rowsForColumns(
          imageWidth: 1,
          imageHeight: 1,
          geometry: rectangular,
          metrics: square,
          columns: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
