import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/palette_builder.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/quantizer.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';

/// Стадия 2 с лицами (T54): 3–4 цвета палитры резервируются на кожу, остальные выбирает основной строитель по
/// остальной картинке.
///
/// Кожу кластеризуем отдельно: на лице оттенки близки, и общая палитра отдала бы ей один-два цвета, а мягкий
/// переход щеки, тени у носа и света на лбу пропал бы. Пиксели кожи на время основного строителя скрываются, чтобы
/// он не тратил на них своих цветов. Без лиц ([PaletteRequest.skinPixels] равен `null`) ведёт себя как основной.
final class FaceAwarePaletteBuilder implements PaletteBuilder {
  const FaceAwarePaletteBuilder({
    this.inner = const AccentPaletteBuilder(),
    this.skinColors = 3,
    this.minSkinPixels = 40,
    this.sampleSize = 6000,
  });

  final PaletteBuilder inner;

  /// Сколько цветов резервировать на кожу (3–4).
  final int skinColors;

  /// Меньше стольких пикселей кожи — лица слишком мелкие, резерва нет.
  final int minSkinPixels;

  final int sampleSize;

  @override
  List<PaletteEntry> build(PaletteRequest request) {
    final Uint8List? skin = request.skinPixels;
    final List<PaletteEntry>? candidates = request.constraint.candidates;
    final int reserve = math.min(skinColors, request.maxColors - 2);
    if (skin == null || reserve < 1 || (candidates != null && candidates.length <= request.maxColors)) {
      return inner.build(request);
    }
    final WorkImage work = request.work;
    final List<int> indices = <int>[
      for (int i = 0; i < skin.length; i++)
        if (skin[i] != 0 && work.alpha[i] >= 0.5) i,
    ];
    if (indices.length < minSkinPixels) return inner.build(request);

    final int stride = math.max(1, indices.length ~/ sampleSize);
    final List<Lab> points = <Lab>[
      for (int n = 0; n < indices.length; n += stride)
        Lab(work.lightness[indices[n]], work.a[indices[n]], work.b[indices[n]]),
    ];
    final Quantization quantization = const LabQuantizer().quantize(
      points,
      List<double>.filled(points.length, 1),
      colors: reserve,
      seed: request.seed,
    );
    List<PaletteEntry> skinEntries = <PaletteEntry>[
      for (final Lab center in quantization.centers) PaletteEntry(rgb: center.toRgb()),
    ];
    if (candidates != null) {
      final NearestColorMatcher<PaletteEntry> matcher = NearestColorMatcher<PaletteEntry>(
        candidates,
        rgbOf: (e) => e.rgb,
      );
      final List<PaletteEntry> snapped = <PaletteEntry>[];
      for (final PaletteEntry entry in skinEntries) {
        // Ближайшая позиция, ещё не взятая для кожи: повторов в палитре быть не должно.
        for (final PaletteEntry near in matcher.nearest(entry.rgb, count: reserve + 1).map((m) => m.item)) {
          if (!snapped.contains(near)) {
            snapped.add(near);
            break;
          }
        }
      }
      skinEntries = snapped;
    } else {
      skinEntries = skinEntries.toSet().toList();
    }

    final Float32List alpha = Float32List.fromList(work.alpha);
    for (final int i in indices) {
      alpha[i] = 0;
    }
    final WorkImage rest = WorkImage(
      width: work.width,
      height: work.height,
      lightness: work.lightness,
      a: work.a,
      b: work.b,
      alpha: alpha,
      importance: work.importance,
      scale: work.scale,
    );
    final List<PaletteEntry> others = inner.build(
      PaletteRequest(
        work: rest,
        maxColors: request.maxColors - skinEntries.length,
        constraint: request.constraint,
        seed: request.seed,
        regions: request.regions,
      ),
    );
    return <PaletteEntry>[
      ...others,
      for (final PaletteEntry e in skinEntries)
        if (!others.contains(e)) e,
    ];
  }
}
