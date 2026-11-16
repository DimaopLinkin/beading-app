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
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gallery_support.dart';

// Листы смешанных стежков (T72): полные кресты и полукресты `/` поверх них, для каждой фикстуры.
//
//     GALLERY_OUT=build/overlays flutter test --tags gallery test/gallery/overlay_gallery_test.dart
const int _cellPx = 8;

ImageToGridRequest _build(GalleryPhoto photo, {required int columns, required bool mask}) {
  final ImageToGridSettings settings = ImageToGridSettings(
    technique: Technique.crossStitch,
    columns: columns,
    maxColors: 30,
    mixedStitches: true,
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
          rgba[o] = rgb.r;
          rgba[o + 1] = rgb.g;
          rgba[o + 2] = rgb.b;
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

  for (final PartialStitch ps in p.partials) {
    final rgb = p.palette[ps.color - 1].rgb;
    for (int i = 0; i <= _cellPx; i++) {
      final int x = ps.column * _cellPx + i;
      final int y = (ps.row + 1) * _cellPx - i;
      dot(x.clamp(0, w - 1), y.clamp(0, h - 1), 1, <int>[rgb.r, rgb.g, rgb.b]);
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
  testWidgets('листы смешанных стежков', (tester) async {
    final String out = Platform.environment['GALLERY_OUT'] ?? 'build/overlays';
    Directory(out).createSync(recursive: true);
    await tester.runAsync(() async {
      final List<GalleryPhoto> photos = await loadPhotos();
      final StringBuffer report = StringBuffer('| фото | полукрестов | доля закрашенных клеток, % |\n|---|---|---|\n');
      for (final GalleryPhoto photo in photos) {
        final GeneratedPattern p = const ImageToGridPipeline().run(_build(photo, columns: 100, mask: false));
        final int cells = p.grid.cells.where((v) => v != 0).length;
        report.writeln(
          '| ${photo.name} | ${p.partials.length} | ${(p.partials.length * 100 / (cells == 0 ? 1 : cells)).toStringAsFixed(1)} |',
        );
        File('$out/${photo.name}.png').writeAsBytesSync(await _panel(p));
      }
      File('$out/report.md').writeAsStringSync(report.toString());
    });
  });
}
