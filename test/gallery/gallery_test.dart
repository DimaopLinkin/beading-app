@Tags(<String>['gallery'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'gallery_support.dart';

/// Строит листы «до / после» и `metrics.md` для всех фикстур (и личных фото из `GALLERY_PHOTOS`).
///
///     flutter test --tags gallery test/gallery/
///
/// Папка результата — `GALLERY_OUT` (по умолчанию `build/gallery`). `GALLERY_UPDATE_BASELINE=1` ещё и пересобирает
/// `test/fixtures/photos/baseline.json`, но только по фикстурам из репозитория (личные фото в базу не попадают).
void main() {
  testWidgets('строит листы и таблицу метрик', (WidgetTester tester) async {
    final String out = Platform.environment['GALLERY_OUT'] ?? 'build/gallery';
    final String? privateDir = Platform.environment['GALLERY_PHOTOS'];
    final bool updateBaseline = Platform.environment['GALLERY_UPDATE_BASELINE'] == '1';
    Directory(out).createSync(recursive: true);

    await tester.runAsync(() async {
      final catalog = loadBeadCatalog();
      final List<GalleryPhoto> photos = await loadPhotos(privateDir: privateDir);
      final List<GalleryRun> runs = runGallery(photos, catalog);

      for (final GalleryPhoto photo in photos) {
        for (final GalleryTarget target in galleryTargets) {
          final List<GalleryRun> own = <GalleryRun>[
            for (final GalleryRun r in runs)
              if (r.photo == photo && r.target == target) r,
          ];
          final Uint8List png = await renderSheet(photo, target, own);
          File('$out/${photo.name}-${target.id}.png').writeAsBytesSync(png);
        }
      }
      File('$out/metrics.md').writeAsStringSync(metricsTable(runs));

      if (updateBaseline) {
        writeBaseline(
          baselineOf(<GalleryRun>[
            for (final GalleryRun r in runs)
              if (!r.photo.name.startsWith('private-')) r,
          ]),
        );
      }
      expect(runs, isNotEmpty);
    });
  });
}
