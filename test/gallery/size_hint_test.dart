@Tags(<String>['gallery'])
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/box_blur.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/size_suggester.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gallery_support.dart';

/// Таблица подсказки размера (T61): корреляция светлоты черновиков на ширинах проб по всем фикстурам и выбранный размер.
///
///     flutter test --tags gallery test/gallery/size_hint_test.dart
void main() {
  SourceImage blurred(SourceImage image) {
    final int radius = math.max(2, image.width ~/ 25);
    final Uint8List out = Uint8List.fromList(image.rgba);
    for (int channel = 0; channel < 3; channel++) {
      final Float32List plane = Float32List(image.width * image.height);
      for (int i = 0; i < plane.length; i++) {
        plane[i] = image.rgba[i * 4 + channel].toDouble();
      }
      final Float32List blur = boxBlur(plane, image.width, image.height, radius);
      for (int i = 0; i < plane.length; i++) {
        out[i * 4 + channel] = blur[i].round().clamp(0, 255);
      }
    }
    return SourceImage(width: image.width, height: image.height, rgba: out);
  }

  SizeSuggestion? hintFor(SourceImage image, Craft craft, {int minColumns = 0}) {
    final List<SizeProbe> probes = <SizeProbe>[];
    for (final c in SizeSuggester.candidates(craft, maxColumns: ImageToGridSettings.maxColumnsOf(craft))) {
      final ImageToGridSettings s = ImageToGridSettings(
        technique: Technique.defaultFor(craft),
        columns: c.columns,
        maxColors: c.colors,
        paletteSource: PaletteSource.free,
      );
      final res = const ImageToGridPipeline().run(s.toRequest(image: image, draft: true, measure: true));
      probes.add(SizeProbe(columns: c.columns, colors: c.colors, correlation: res.stats!.lightnessCorrelation));
    }
    return const SizeSuggester().choose(probes, minColumns: minColumns);
  }

  testWidgets('подсказка размера по галерее', (tester) async {
    await tester.runAsync(() async {
      final List<GalleryPhoto> photos = await loadPhotos();
      for (final Craft craft in Craft.values) {
        for (final GalleryPhoto p in photos) {
          final bool subject = p.name == 'cat' || p.name == 'portrait';
          final SizeSuggestion? plain = hintFor(p.image, craft);
          final SizeSuggestion? hint = hintFor(p.image, craft, minColumns: subject && craft == Craft.beading ? 80 : 0);
          final SizeSuggestion? soft = hintFor(blurred(p.image), craft);
          // Таблица для PR печатается намеренно.
          // ignore: avoid_print
          print(
            'RESULT ${craft.name} ${p.name}: ${plain?.columns}/${plain?.colors} reached=${plain?.reached}'
            ' с полом ${hint?.columns} размытая ${soft?.columns}',
          );
          if (subject && craft == Craft.beading) {
            expect(hint!.columns, greaterThanOrEqualTo(80), reason: p.name);
          }
          // Подсказка не растёт, когда фото заменено его же размытой копией (у размытой копии выше корреляция).
          if (plain != null && soft != null && plain.reached) {
            expect(soft.columns, lessThanOrEqualTo(plain.columns), reason: '${craft.name} ${p.name}');
          }
        }
      }
    });
  }, timeout: const Timeout(Duration(minutes: 20)));
}
