@Tags(<String>['gallery'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gallery_support.dart';

/// Самая большая вышивка: 200 × 80 см на Аиде 14 (около 1100 × 440 крестиков) и 120 цветов в настройках.
///
///     flutter test --tags gallery test/gallery/large_stitch_test.dart
///
/// Печатает время и пиковую память этого компьютера; проверяет, что схема собирается и укладывается в бюджет цветов.
void main() {
  testWidgets('вышивка 200 × 80 см собирается за разумное время', (tester) async {
    await tester.runAsync(() async {
      final List<CatalogColor> catalog = loadBeadCatalog();
      final List<GalleryPhoto> photos = await loadPhotos();
      final GalleryPhoto photo = photos.firstWhere((p) => p.name == 'landscape', orElse: () => photos.first);
      // Фото растягиваем до 2048 × 819 — как после мастера, пропорции 2,5 : 1.
      final SourceImage image = _stretch(photo.image, 2048, 819);
      final ImageToGridSettings settings = const ImageToGridSettings(
        technique: Technique.crossStitch,
      ).copyWith(columns: Fabric.standard.cellsForCm(200), maxColors: ImageToGridSettings.maxColorsLimit);
      final int rows = settings.rowsFor(image);
      final int colors = settings.colorsFor(rows);
      final Stopwatch watch = Stopwatch()..start();
      final GeneratedPattern pattern = const ImageToGridPipeline().run(
        settings.toRequest(image: image, catalog: catalog, measure: true),
      );
      watch.stop();
      stdout.writeln(
        '${settings.columns}×$rows клеток, цветов в расчёте $colors, ${watch.elapsedMilliseconds} мс, '
        'пиковая память ${(ProcessInfo.maxRss / 1048576).toStringAsFixed(0)} МБ',
      );
      expect(pattern.grid.width, settings.columns);
      expect(pattern.grid.height, rows);
      expect(pattern.palette.length, lessThanOrEqualTo(colors));
    });
  }, timeout: const Timeout(Duration(minutes: 15)));
}

SourceImage _stretch(SourceImage src, int w, int h) {
  final List<int> out = List<int>.filled(w * h * 4, 255);
  for (int y = 0; y < h; y++) {
    final int sy = y * src.height ~/ h;
    for (int x = 0; x < w; x++) {
      final int sx = x * src.width ~/ w;
      final int s = (sy * src.width + sx) * 4;
      final int d = (y * w + x) * 4;
      for (int c = 0; c < 4; c++) {
        out[d + c] = src.rgba[s + c];
      }
    }
  }
  return SourceImage(width: w, height: h, rgba: Uint8List.fromList(out));
}
