import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/cell_labeler.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_prefilter.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/palette_builder.dart';
import 'package:beading/domain/image_to_grid/palette_constraint.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import '../grid/fake_cell_metrics.dart';

SourceImage _image(int w, int h, int Function(int x, int y) color) {
  final Uint8List bytes = Uint8List(w * h * 4);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final int c = color(x, y);
      final int o = (y * w + x) * 4;
      bytes[o] = (c >> 16) & 255;
      bytes[o + 1] = (c >> 8) & 255;
      bytes[o + 2] = c & 255;
      bytes[o + 3] = 255;
    }
  }
  return SourceImage(width: w, height: h, rgba: bytes);
}

GeneratedPattern _run(SourceImage image, int columns, int rows, CellLabeler labeler, {bool prefilter = false}) =>
    const ImageToGridPipeline().run(
      ImageToGridRequest(
        image: image,
        geometry: const GridGeometry.rectangular(),
        metrics: const FakeCellMetrics(1, 1),
        columns: columns,
        rows: rows,
        maxColors: 2,
        constraint: PaletteConstraint.list(const <PaletteEntry>[
          PaletteEntry(rgb: Rgb(245, 245, 245)),
          PaletteEntry(rgb: Rgb(20, 20, 20)),
        ]),
        prefilter: prefilter ? const EdgePreservingPrefilter() : null,
        paletteBuilder: const AccentPaletteBuilder(),
        labeler: labeler,
      ),
    );

void main() {
  group('DetailCellLabeler', () {
    test('тёмная линия в шестую часть клетки через пять клеток остаётся линией из пяти клеток', () {
      // 5 × 5 клеток по 6 пикселей; линия шириной 1 пиксель посередине третьего столбца.
      final SourceImage image = _image(30, 30, (x, y) => x == 15 ? 0x141414 : 0xF5F5F5);
      final GeneratedPattern plain = _run(image, 5, 5, const VotingCellLabeler());
      final GeneratedPattern detail = _run(image, 5, 5, const DetailCellLabeler());
      final int dark = detail.palette.indexWhere((e) => e.rgb == const Rgb(20, 20, 20)) + 1;
      expect(<int>[for (int row = 0; row < 5; row++) detail.grid.at(2, row)], everyElement(dark));
      // Без веса заметности линия растворяется в фоне: тест различает разметчики.
      expect(plain.palette, hasLength(1));
    });

    test('диагональная линия тоже остаётся', () {
      final SourceImage image = _image(30, 30, (x, y) => (x - y).abs() <= 0 ? 0x141414 : 0xF5F5F5);
      final GeneratedPattern detail = _run(image, 5, 5, const DetailCellLabeler());
      final int dark = detail.palette.indexWhere((e) => e.rgb == const Rgb(20, 20, 20)) + 1;
      expect(dark, greaterThan(0));
      expect(<int>[for (int i = 0; i < 5; i++) detail.grid.at(i, i)], everyElement(dark));
    });

    test('шум ±10 по RGB на однотонной картинке не даёт ни одной клетки другого цвета', () {
      final math.Random random = math.Random(7);
      final SourceImage image = _image(60, 60, (x, y) {
        final int v = 128 + random.nextInt(21) - 10;
        return (v << 16) | (v << 8) | v;
      });
      for (final bool prefilter in <bool>[false, true]) {
        final GeneratedPattern result = _run(image, 10, 10, const DetailCellLabeler(), prefilter: prefilter);
        expect(result.grid.cells.toSet(), hasLength(1), reason: 'префильтр: $prefilter');
      }
    });

    test('цены и значения того же размера, что у голосования; пустые клетки остаются пустыми', () {
      // Заметность не меняет число клеток и цветов.
      final SourceImage image = _image(30, 30, (x, y) => x < 15 ? 0xF5F5F5 : 0x141414);
      final GeneratedPattern a = _run(image, 5, 5, const VotingCellLabeler());
      final GeneratedPattern b = _run(image, 5, 5, const DetailCellLabeler());
      expect(b.grid.width, a.grid.width);
      expect(b.grid.cells, a.grid.cells); // ровный край без тонких деталей: те же клетки
    });
  });
}
