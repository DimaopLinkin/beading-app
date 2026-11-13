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
  testWidgets('строит листы и таблицу метрик', (tester) async {
    final String out = Platform.environment['GALLERY_OUT'] ?? 'build/gallery';
    final String? privateDir = Platform.environment['GALLERY_PHOTOS'];
    final bool updateBaseline = Platform.environment['GALLERY_UPDATE_BASELINE'] == '1';
    Directory(out).createSync(recursive: true);

    await tester.runAsync(() async {
      final catalog = loadBeadCatalog();
      final List<GalleryPhoto> photos = await loadPhotos(privateDir: privateDir);
      // GALLERY_VARIANTS=t24,v2-balanced: листы только этих вариантов (в базу метрик такой прогон не пишется).
      final Set<String>? only = Platform.environment['GALLERY_VARIANTS']?.split(',').toSet();
      final List<GalleryRun> runs = <GalleryRun>[
        for (final GalleryRun r in runGallery(photos, catalog, includeLarge: true))
          if (only == null || only.contains(r.variant.id)) r,
      ];

      for (final GalleryPhoto photo in photos) {
        for (final GalleryTarget target in <GalleryTarget>[...galleryTargets, ...galleryLargeTargets]) {
          final List<GalleryRun> own = <GalleryRun>[
            for (final GalleryRun r in runs)
              if (r.photo == photo && r.target == target) r,
          ];
          // Лист «как будет выглядеть» и плоский («до», как было до T56).
          final Uint8List real = await renderSheet(photo, target, own, realistic: true);
          File('$out/${photo.name}-${target.id}.png').writeAsBytesSync(real);
          final Uint8List flat = await renderSheet(photo, target, own);
          File('$out/${photo.name}-${target.id}-flat.png').writeAsBytesSync(flat);
        }
      }
      File('$out/metrics.md').writeAsStringSync(metricsTable(runs));

      if (updateBaseline && only == null) {
        writeBaseline(
          baselineOf(<GalleryRun>[
            for (final GalleryRun r in runs)
              if (!r.photo.name.startsWith('private-') && !r.target.large) r,
          ]),
        );
      }
      expect(runs, isNotEmpty);
    });
  });
}
