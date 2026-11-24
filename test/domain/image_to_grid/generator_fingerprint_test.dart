import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/image_to_grid/background_stage.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
import 'package:beading/domain/image_to_grid/generator_version.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';

/// Охрана [GeneratorVersion] (ADR-0009): схемы на эталонной картинке с разными ветками конвейера не должны меняться
/// молча. Если тест упал, результат генератора изменился. Если так и задумано, поднимите
/// [GeneratorVersion.current], запишите изменение в `docs/research/generator-versions.md` и обновите отпечатки ниже
/// (новые значения печатает сам тест). Если не задумано, это регрессия.
///
/// Картинка синтетическая, без случайных чисел; хэшируются индексы сетки, цвета палитры и число контуров, а не
/// метрики с плавающей запятой.
const int _expectedVersion = 2;

const Map<String, String> _expected = <String, String>{
  'beads': 'fe66a8871bb60509',
  'stitch': 'c4e8ca11a7e5ef7c',
  'stitch-simple': '9e367fcc95848fc3',
  'stitch-dither': '8cfd15b7829ddea6',
  'stitch-shadows': '6ae2b2330171c3c8',
};

SourceImage _scene() {
  const int w = 96;
  const int h = 80;
  final Uint8List bytes = Uint8List(w * h * 4);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final int o = (y * w + x) * 4;
      // Градиент неба, «солнце», тёмный холм и яркая точка-акцент.
      double r = 40 + 160 * x / w;
      double g = 90 + 100 * y / h;
      double b = 200 - 120 * y / h;
      final double dSun = math.sqrt(math.pow(x - 70, 2) + math.pow(y - 18, 2));
      if (dSun < 10) {
        r = 250;
        g = 220;
        b = 80;
      }
      if (y > 50 + 8 * math.sin(x / 9)) {
        r = 30 + x / 4;
        g = 70;
        b = 40;
      }
      if ((x - 20).abs() + (y - 62).abs() < 4) {
        r = 220;
        g = 30;
        b = 120;
      }
      if (y >= h - 28) {
        // Тени от почти чёрного до среднего: в каталоге мулине между чёрным и тёмно-серым пробел, работает подъём теней.
        final double t = (y - (h - 28)) / 28;
        r = 12 + 100 * (1 - t) * (0.4 + 0.6 * x / w);
        g = 14 + 95 * (1 - t) * (0.4 + 0.6 * x / w);
        b = 26 + 100 * (1 - t) * (0.4 + 0.6 * x / w);
      }
      bytes[o] = r.round().clamp(0, 255);
      bytes[o + 1] = g.round().clamp(0, 255);
      bytes[o + 2] = b.round().clamp(0, 255);
      bytes[o + 3] = 255;
    }
  }
  return SourceImage(width: w, height: h, rgba: bytes);
}

String _fingerprint(GeneratedPattern p) {
  final StringBuffer text = StringBuffer()
    ..write('${p.grid.width}x${p.grid.height};')
    ..writeAll(p.grid.cells, ',')
    ..write(';')
    ..writeAll(<String>[for (final PaletteEntry e in p.palette) '${e.rgb.r}.${e.rgb.g}.${e.rgb.b}'], ',')
    ..write(';lines=${p.lines.length};partials=${p.partials.length}');
  return sha256.convert(utf8.encode(text.toString())).toString().substring(0, 16);
}

CatalogColor _thread(String code, Lab lab) =>
    catalogColor(code, 'Нитка $code', lab.toRgb().hex, brand: 'DMC', material: CatalogMaterial.floss);

/// Небольшой каталог мулине с пробелом в тёмных тонах.
final List<CatalogColor> _floss = <CatalogColor>[
  _thread('310', const Lab(0, 0, 0)),
  _thread('3750', const Lab(33, 3, 5)),
  _thread('3768', const Lab(48, 0, 3)),
  _thread('335', const Lab(52, 55, 12)),
  _thread('762', const Lab(72, 0, 0)),
  _thread('3865', const Lab(88, 1, 3)),
  _thread('3846', const Lab(70, -30, -20)),
  _thread('729', const Lab(65, 12, 45)),
];

void main() {
  const ImageToGridPipeline pipeline = ImageToGridPipeline();
  final SourceImage scene = _scene();

  final Map<String, ImageToGridSettings> variants = <String, ImageToGridSettings>{
    'beads': const ImageToGridSettings(maxColors: 12),
    'stitch': const ImageToGridSettings(technique: Technique.crossStitch, columns: 60, maxColors: 20),
    'stitch-simple': ImageToGridSettings(
      technique: Technique.crossStitch,
      columns: 60,
      maxColors: 14,
      preset: GenerationPreset.simpler,
      outline: true,
      backstitch: true,
      background: BackgroundMode.values.last,
    ),
    'stitch-dither': const ImageToGridSettings(
      technique: Technique.crossStitch,
      columns: 50,
      maxColors: 16,
      dither: true,
      mixedStitches: true,
    ),
    'stitch-shadows': const ImageToGridSettings(
      technique: Technique.crossStitch,
      columns: 60,
      shadows: 80,
    ),
  };

  test('версия генератора совпадает с версией отпечатков', () {
    expect(GeneratorVersion.current, _expectedVersion, reason: 'обновите _expectedVersion вместе с отпечатками ниже');
  });

  for (final MapEntry<String, ImageToGridSettings> variant in variants.entries) {
    test('отпечаток схемы «${variant.key}» не менялся (algo ${GeneratorVersion.current})', () {
      final GeneratedPattern result = pipeline.run(
        variant.value.toRequest(image: scene, catalog: _floss, brand: 'DMC'),
      );
      final String actual = _fingerprint(result);
      expect(
        actual,
        _expected[variant.key],
        reason:
            'Результат генератора изменился. Поднимите GeneratorVersion.current, допишите docs/research/generator-versions.md '
            'и обновите отпечаток "${variant.key}": $actual',
      );
    });
  }
}
