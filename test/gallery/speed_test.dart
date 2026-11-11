@Tags(<String>['gallery'])
library;

import 'dart:io';

import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
import 'package:beading/domain/image_to_grid/generation_stats.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_session.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/label_smoother.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gallery_support.dart';

/// Скорость генератора (T58): время стадий холодного и тёплого расчёта по галерее и листы «черновик / полный».
///
///     flutter test --tags gallery test/gallery/speed_test.dart
///
/// Результат в `GALLERY_OUT` (по умолчанию `build/gallery-speed`): `speed.md` и листы `<фото>-<вид>-draft.png`.
/// Время — этого компьютера, а не телефона: цифры для iPhone снимаются вручную (см. `docs/plan` T58 и PR).
void main() {
  testWidgets('замеры скорости и листы черновика', (tester) async {
    final String out = Platform.environment['GALLERY_OUT'] ?? 'build/gallery-speed';
    final String? privateDir = Platform.environment['GALLERY_PHOTOS'];
    Directory(out).createSync(recursive: true);
    await tester.runAsync(() async {
      final List<CatalogColor> catalog = loadBeadCatalog();
      final List<GalleryPhoto> photos = await loadPhotos(privateDir: privateDir);
      final GalleryVariant balanced = galleryVariants.firstWhere((v) => v.id == 't47-balanced');
      final GalleryVariant draftVariant = GalleryVariant(
        id: 't58-draft',
        title: 'T58: черновик',
        build: (image, target, catalog) => _withDraft(balanced.build(image, target, catalog)),
      );
      final StringBuffer table = StringBuffer()
        ..writeln(
          'Время в мс на этом компьютере (Linux, Dart JIT в тесте), не на телефоне. «Выборка» — рабочая картинка, фильтр,',
        )
        ..writeln(
          'цвета клеток; «палитра»; «привязка» — разметка, сглаживание, сборка; «шаги» — очистка. Сумма — только сами стадии.',
        )
        ..writeln()
        ..writeln('| Фото | Вид | Расчёт | Выборка | Палитра | Привязка | Шаги | Сумма | Одиночных | ΔE |')
        ..writeln('|---|---|---|---|---|---|---|---|---|---|');
      String row(String photo, String target, String name, GeneratedPattern p) {
        final GenerationStats s = p.stats!;
        String ms(String stage) => (s.stageTimes[stage]!.inMicroseconds / 1000).toStringAsFixed(0);
        return '| $photo | $target | $name | ${ms('sample')} | ${ms('palette')} | ${ms('assign')} | ${ms('steps')} | '
            '${(s.totalTime.inMicroseconds / 1000).toStringAsFixed(0)} | ${s.singleCells} | ${s.meanDeltaE.toStringAsFixed(1)} |';
      }

      for (final GalleryPhoto photo in photos) {
        for (final GalleryTarget target in galleryTargets) {
          final ImageToGridRequest base = balanced.build(photo.image, target, catalog);
          final ImageToGridSession session = ImageToGridSession();
          final GeneratedPattern full = session.run(base);
          final GeneratedPattern cold = const ImageToGridPipeline().run(base);
          if (full.grid != cold.grid) fail('${photo.name}/${target.id}: сессия и разовый запуск дали разные схемы');
          final GeneratedPattern cleanup = session.run(_with(base, preset: GenerationPreset.balanced, detail: 0.9));
          final GeneratedPattern colors = session.run(_with(base, maxColors: target.maxColors - 2));
          final GeneratedPattern draft = session.run(_withDraft(base));
          final GeneratedPattern draftAgain = session.run(_with(_withDraft(base), detail: 0.9, draftPalette: true));
          table
            ..writeln(row(photo.name, target.id, 'полный, с нуля', full))
            ..writeln(row(photo.name, target.id, 'ползунок очистки', cleanup))
            ..writeln(row(photo.name, target.id, 'число цветов −2', colors))
            ..writeln(row(photo.name, target.id, 'черновик, с нуля', draft))
            ..writeln(row(photo.name, target.id, 'черновик, очистка', draftAgain));
          final List<GalleryRun> own = <GalleryRun>[
            GalleryRun(photo: photo, target: target, variant: balanced, pattern: full),
            GalleryRun(photo: photo, target: target, variant: draftVariant, pattern: draft),
          ];
          File('$out/${photo.name}-${target.id}-draft.png').writeAsBytesSync(await renderSheet(photo, target, own));
        }
      }
      // Верхний случай приёмки T58: схема 150×200 и 30 цветов.
      table
        ..writeln()
        ..writeln('Верхний случай: 150×200 клеток, 30 цветов (станок, Delica 11/0), «сбалансированно».')
        ..writeln()
        ..writeln('| Фото | Расчёт | Выборка | Палитра | Привязка | Шаги | Сумма | Одиночных | ΔE |')
        ..writeln('|---|---|---|---|---|---|---|---|---|');
      for (final GalleryPhoto photo in photos) {
        final ImageToGridRequest big = _big(balanced.build(photo.image, galleryTargets.first, catalog));
        final ImageToGridSession session = ImageToGridSession();
        for (final (String name, ImageToGridRequest request) in <(String, ImageToGridRequest)>[
          ('полный, с нуля', big),
          ('ползунок очистки', _with(big, detail: 0.9)),
          ('число цветов −2', _with(big, maxColors: 28)),
          ('черновик, с нуля', _withDraft(big)),
          ('черновик, очистка', _with(_withDraft(big), detail: 0.9, draftPalette: true)),
          ('черновик, число цветов −2', _with(_withDraft(big), maxColors: 28, draftPalette: true)),
        ]) {
          final GeneratedPattern p = session.run(request);
          table.writeln(row(photo.name, '', name, p).replaceFirst('|  |', '|'));
        }
      }
      File('$out/speed.md').writeAsStringSync(table.toString());
      expect(photos, isNotEmpty);
    });
  });
}

/// Тот же запрос на сетке 150×200 и с 30 цветами.
ImageToGridRequest _big(ImageToGridRequest r) => ImageToGridRequest(
  image: r.image,
  geometry: r.geometry,
  metrics: r.metrics,
  columns: 150,
  rows: 200,
  maxColors: 30,
  prefilter: r.prefilter,
  paletteBuilder: r.paletteBuilder,
  labeler: r.labeler,
  smoother: r.smoother,
  refillFreedColors: r.refillFreedColors,
  steps: r.steps,
);

ImageToGridRequest _withDraft(ImageToGridRequest r) => _with(r, draft: true, draftPalette: true);

/// Тот же запрос с изменёнными параметрами; `detail` меняет только ползунок сглаживания (стадии 4–5).
ImageToGridRequest _with(
  ImageToGridRequest r, {
  bool? draft,
  bool draftPalette = false,
  int? maxColors,
  GenerationPreset? preset,
  double? detail,
}) {
  final GenerationPreset? p = preset;
  return ImageToGridRequest(
    image: r.image,
    geometry: r.geometry,
    metrics: r.metrics,
    columns: r.columns,
    rows: r.rows,
    maxColors: maxColors ?? r.maxColors,
    constraint: r.constraint,
    importance: r.importance,
    dither: r.dither,
    seed: r.seed,
    prefilter: r.prefilter,
    paletteBuilder: draftPalette ? ImageToGridSettings.draftPaletteBuilder : r.paletteBuilder,
    labeler: r.labeler,
    smoother: detail == null ? r.smoother : PottsLabelSmoother(detail: detail),
    refillFreedColors: p?.refillFreedColors ?? r.refillFreedColors,
    draft: draft ?? r.draft,
    steps: p?.steps ?? r.steps,
  );
}
