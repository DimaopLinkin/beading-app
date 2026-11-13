@Tags(<String>['gallery'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gallery_support.dart';

// Листы бэкстича (A10-1): «крестики + линии» для каждой фикстуры, с маской объекта и без.
//
//     GALLERY_OUT=build/backstitch flutter test --tags gallery test/gallery/backstitch_gallery_test.dart
const int _cellPx = 8;

ImageToGridRequest _build(GalleryPhoto photo, {required int columns, required bool mask}) {
  final ImageToGridSettings settings = ImageToGridSettings(
    technique: Technique.crossStitch,
    columns: columns,
    maxColors: 30,
    backstitch: true,
  );
  return settings.toRequest(
    image: photo.image,
    masks: galleryFaces[photo.image],
    subjectMask: mask ? standInSubjectMask(photo.image) : null,
  );
}

Future<Uint8List> _panel(GeneratedPattern p) async {
  final int w = p.grid.width * _cellPx;
  final int h = p.grid.height * _cellPx;
  final Uint8List rgba = Uint8List(w * h * 4)..fillRange(0, w * h * 4, 255);
  for (int row = 0; row < p.grid.height; row++) {
    for (int col = 0; col < p.grid.width; col++) {
      final int v = p.grid.at(col, row);
      if (v == 0) continue;
      final rgb = p.palette[v - 1].rgb;
      for (int y = row * _cellPx; y < (row + 1) * _cellPx; y++) {
        for (int x = col * _cellPx; x < (col + 1) * _cellPx; x++) {
          final int o = (y * w + x) * 4;
          // Крестики бледнее, чтобы линии были видны.
          rgba[o] = (rgb.r * 0.55 + 255 * 0.45).round();
          rgba[o + 1] = (rgb.g * 0.55 + 255 * 0.45).round();
          rgba[o + 2] = (rgb.b * 0.55 + 255 * 0.45).round();
        }
      }
    }
  }
  void dot(int cx, int cy, int r, List<int> c) {
    for (int y = cy - r; y <= cy + r; y++) {
      for (int x = cx - r; x <= cx + r; x++) {
        if (x < 0 || y < 0 || x >= w || y >= h) continue;
        final int o = (y * w + x) * 4;
        rgba[o] = c[0];
        rgba[o + 1] = c[1];
        rgba[o + 2] = c[2];
      }
    }
  }

  for (final LineStitch l in p.lines) {
    final double x0 = l.from.x * _cellPx / 2;
    final double y0 = l.from.y * _cellPx / 2;
    final double x1 = l.to.x * _cellPx / 2;
    final double y1 = l.to.y * _cellPx / 2;
    final int steps = ((x1 - x0).abs() + (y1 - y0).abs()).ceil() * 2 + 1;
    for (int i = 0; i <= steps; i++) {
      final double t = i / steps;
      dot((x0 + (x1 - x0) * t).round(), (y0 + (y1 - y0) * t).round(), 1, const <int>[200, 0, 60]);
    }
  }
  final Completer<ui.Image> c = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
  final ui.Image img = await c.future;
  final ByteData? png = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return png!.buffer.asUint8List();
}

void main() {
  testWidgets('листы бэкстича', (tester) async {
    final String out = Platform.environment['GALLERY_OUT'] ?? 'build/backstitch';
    Directory(out).createSync(recursive: true);
    await tester.runAsync(() async {
      final List<GalleryPhoto> photos = await loadPhotos();
      final StringBuffer report = StringBuffer(
        '| фото | маска | линий | длина, клеток | на 100 клеток |\n|---|---|---|---|---|\n',
      );
      for (final GalleryPhoto photo in photos) {
        for (final bool mask in <bool>[true, false]) {
          final GeneratedPattern p = const ImageToGridPipeline().run(_build(photo, columns: 100, mask: mask));
          double len = 0;
          for (final LineStitch l in p.lines) {
            len += ((l.to.x - l.from.x).abs() + (l.to.y - l.from.y).abs()) / 2;
          }
          final int cells = p.grid.cells.where((v) => v != 0).length;
          report.writeln(
            '| ${photo.name} | ${mask ? 'да' : 'нет'} | ${p.lines.length} | ${len.toStringAsFixed(0)} | ${(len * 100 / (cells == 0 ? 1 : cells)).toStringAsFixed(1)} |',
          );
          File('$out/${photo.name}-${mask ? 'mask' : 'nomask'}.png').writeAsBytesSync(await _panel(p));
        }
      }
      File('$out/report.md').writeAsStringSync(report.toString());
    });
  });
}
