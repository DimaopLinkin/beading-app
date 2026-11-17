import 'dart:typed_data';

import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/cell_labeler.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_session.dart';
import 'package:beading/domain/image_to_grid/palette_builder.dart';
import 'package:beading/domain/image_to_grid/palette_constraint.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/shadow_lift.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';
import '../grid/fake_cell_metrics.dart';

/// Картинка из прямоугольников Lab: каждая запись — доля ширины и цвет; ряды одинаковые.
SourceImage _stripes(List<(int, Lab)> parts, {int height = 40}) {
  final int width = parts.fold(0, (sum, p) => sum + p.$1);
  final Uint8List bytes = Uint8List(width * height * 4);
  for (int y = 0; y < height; y++) {
    int x = 0;
    for (final (int w, Lab lab) in parts) {
      final Rgb rgb = lab.toRgb();
      for (int i = 0; i < w; i++, x++) {
        final int o = (y * width + x) * 4;
        bytes[o] = rgb.r;
        bytes[o + 1] = rgb.g;
        bytes[o + 2] = rgb.b;
        bytes[o + 3] = 255;
      }
    }
  }
  return SourceImage(width: width, height: height, rgba: bytes);
}

CatalogColor _thread(String code, Lab lab) =>
    catalogColor(code, 'Нитка $code', lab.toRgb().hex, brand: 'DMC', material: CatalogMaterial.floss);

/// Небольшой каталог в духе мулине: чёрный, потом пробел до L ≈ 33, светлые и белая.
final List<CatalogColor> _sparse = <CatalogColor>[
  _thread('310', const Lab(0, 0, 0)),
  _thread('3750', const Lab(33, 3, 5)),
  _thread('3768', const Lab(48, 0, 3)),
  _thread('762', const Lab(72, 0, 0)),
  _thread('3865', const Lab(88, 1, 3)),
];

List<Lab> _labs(List<CatalogColor> colors) => <Lab>[for (final CatalogColor c in colors) Lab.fromRgb(c.rgb)];

/// Строитель палитры, который считает вызовы.
final class _SpyPalette implements PaletteBuilder {
  int calls = 0;

  @override
  List<PaletteEntry> build(PaletteRequest request) {
    calls++;
    return const AccentPaletteBuilder().build(request);
  }
}

void main() {
  group('кривая теней', () {
    test('γ = 1 ничего не меняет', () {
      for (final double l in <double>[0, 5, 18, 40, 59, 60, 80, 100]) {
        expect(ShadowLift.liftL(l, 1), closeTo(l, 1e-9));
      }
    });

    test('светлее 60 не меняется при любом γ', () {
      for (final double l in <double>[60, 61, 75, 100]) {
        expect(ShadowLift.liftL(l, 0.5), closeTo(l, 1e-9));
      }
    });

    test('глубокая тень становится светлее, чёрное и белое остаются на местах', () {
      expect(ShadowLift.liftL(0, 0.5), closeTo(0, 1e-9));
      expect(ShadowLift.liftL(100, 0.5), closeTo(100, 1e-9));
      expect(ShadowLift.liftL(18, 0.6), closeTo(32.0, 0.3));
      expect(ShadowLift.liftL(10, 0.5), greaterThan(ShadowLift.liftL(10, 0.8)));
      expect(ShadowLift.liftL(18, 0.6), greaterThan(18));
    });

    test('значения вне 0..100 прижимаются', () {
      expect(ShadowLift.liftL(-5, 0.5), closeTo(0, 1e-9));
      expect(ShadowLift.liftL(120, 0.5), closeTo(100, 1e-9));
    });

    test('меняется только L: a и b сохраняются', () {
      const Lab src = Lab(18, 6, -4);
      final Lab out = ShadowLift.liftLab(src, 0.6);
      expect(out.a, src.a);
      expect(out.b, src.b);
      expect(out.l, greaterThan(src.l));
    });

    test('проценты и γ: 0 % → 1, 100 % → 0,5, связь обратима для шага 20', () {
      expect(ShadowLift.gammaForPercent(0), 1);
      expect(ShadowLift.gammaForPercent(100), 0.5);
      expect(ShadowLift.gammaForPercent(40), closeTo(0.8, 1e-12));
      expect(ShadowLift.gammaForPercent(-10), 1);
      expect(ShadowLift.gammaForPercent(150), 0.5);
      for (final int p in <int>[0, 20, 40, 60, 80, 100]) {
        expect(ShadowLift.percentForGamma(ShadowLift.gammaForPercent(p)), p);
      }
    });
  });

  group('подъём картинки', () {
    test('при γ = 1 возвращается тот же объект', () {
      final SourceImage image = _stripes(<(int, Lab)>[(4, const Lab(15, 5, 5))]);
      expect(identical(ShadowLift.liftImage(image, 1), image), isTrue);
    });

    test('тёмные пиксели светлеют, светлые и прозрачность остаются', () {
      final SourceImage image = _stripes(<(int, Lab)>[(2, const Lab(15, 5, 5)), (2, const Lab(80, 5, 5))]);
      image.rgba[3] = 100;
      final SourceImage lifted = ShadowLift.liftImage(image, 0.6);
      expect(lifted.width, image.width);
      expect(lifted.height, image.height);
      expect(Lab.fromRgb(Rgb(lifted.rgba[0], lifted.rgba[1], lifted.rgba[2])).l, greaterThan(25));
      expect(lifted.rgba[3], 100);
      for (int i = 3 * 4; i < 4 * 4; i++) {
        expect(lifted.rgba[i], image.rgba[i], reason: 'светлый пиксель не тронут');
      }
      expect(image.rgba[0], const Lab(15, 5, 5).toRgb().r, reason: 'исходник не изменён');
    });
  });

  group('автоматическая сила', () {
    test('большая тёмная тёплая область без ниток поблизости: γ < 1', () {
      final SourceImage image = _stripes(<(int, Lab)>[(90, const Lab(18, 5, 4)), (10, const Lab(85, 1, 3))]);
      final double gamma = ShadowLift.autoGamma(image, _labs(_sparse));
      expect(gamma, lessThan(1));
      expect(gamma, greaterThanOrEqualTo(0.5));
    });

    test('средние тона: 1,0', () {
      final SourceImage image = _stripes(<(int, Lab)>[(50, const Lab(72, 0, 1)), (50, const Lab(88, 1, 3))]);
      expect(ShadowLift.autoGamma(image, _labs(_sparse)), 1);
    });

    test('если нитка в тени есть, поднимать не нужно', () {
      final SourceImage image = _stripes(<(int, Lab)>[(100, const Lab(33, 3, 5))]);
      expect(ShadowLift.autoGamma(image, _labs(_sparse)), 1);
    });

    test('прозрачная картинка не ломает выбор', () {
      final SourceImage image = SourceImage(width: 2, height: 2, rgba: Uint8List(16));
      expect(ShadowLift.autoGamma(image, _labs(_sparse)), 1);
    });

    test('большая картинка уменьшается до ~17 600 образцов и всё равно решает так же', () {
      final SourceImage image = _stripes(<(int, Lab)>[
        (900, const Lab(18, 5, 4)),
        (100, const Lab(85, 1, 3)),
      ], height: 600);
      expect(ShadowLift.autoGamma(image, _labs(_sparse)), lessThan(1));
    });
  });

  group('в конвейере', () {
    final SourceImage dark = _stripes(<(int, Lab)>[(30, const Lab(12, 4, 3)), (10, const Lab(85, 1, 3))]);
    final PaletteConstraint catalog = PaletteConstraint.catalog(_sparse, material: CatalogMaterial.floss);

    ImageToGridRequest request({
      PaletteConstraint? constraint,
      bool liftShadows = true,
      int? shadows,
      SourceImage? image,
      PaletteBuilder? paletteBuilder,
      CellLabeler? labeler,
    }) => ImageToGridRequest(
      image: image ?? dark,
      geometry: const GridGeometry.rectangular(),
      metrics: const FakeCellMetrics(1, 1),
      columns: 8,
      rows: 8,
      maxColors: 5,
      constraint: constraint ?? catalog,
      liftShadows: liftShadows,
      shadows: shadows,
      paletteBuilder: paletteBuilder,
      labeler: labeler,
    );

    test('автоматический режим: выбранный процент попадает в статистику', () {
      final int? percent = const ImageToGridPipeline().run(request()).stats?.shadowPercent;
      expect(percent, isNotNull);
      expect(percent, greaterThan(0));
    });

    test('ручное значение попадает в статистику как есть', () {
      expect(const ImageToGridPipeline().run(request(shadows: 60)).stats?.shadowPercent, 60);
      expect(const ImageToGridPipeline().run(request(shadows: 0)).stats?.shadowPercent, 0);
    });

    test('без запроса, со свободной палитрой: подъёма нет, процент не указан', () {
      expect(const ImageToGridPipeline().run(request(liftShadows: false)).stats?.shadowPercent, isNull);
      expect(
        const ImageToGridPipeline().run(request(constraint: const PaletteConstraint.free())).stats?.shadowPercent,
        isNull,
      );
    });

    test('подъём тёмного даёт в схеме нитку из пробела каталога, без подъёма — чёрную', () {
      final Set<String> lifted = const ImageToGridPipeline()
          .run(request(shadows: 100))
          .palette
          .map((e) => e.catalog!.code)
          .toSet();
      final Set<String> plain = const ImageToGridPipeline()
          .run(request(shadows: 0))
          .palette
          .map((e) => e.catalog!.code)
          .toSet();
      expect(lifted, contains('3750'));
      expect(plain, isNot(contains('3750')));
    });

    test('пиксельный путь тоже видит поднятую картинку', () {
      ImageToGridRequest pixel(int shadows) =>
          request(shadows: shadows, paletteBuilder: const AccentPaletteBuilder(), labeler: const VotingCellLabeler());
      final GeneratedPattern lifted = const ImageToGridPipeline().run(pixel(100));
      final GeneratedPattern plain = const ImageToGridPipeline().run(pixel(0));
      expect(lifted.stats?.shadowPercent, 100);
      expect(lifted.palette.map((e) => e.catalog!.code), contains('3750'));
      expect(plain.palette.map((e) => e.catalog!.code), isNot(contains('3750')));
    });

    test('сессия не пересчитывает палитру, если картинка и сила те же (кеш стадий жив)', () {
      final _SpyPalette spy = _SpyPalette();
      ImageToGridRequest pixel({int? shadows}) =>
          request(shadows: shadows, paletteBuilder: spy, labeler: const VotingCellLabeler());
      final ImageToGridSession session = ImageToGridSession();
      session.run(pixel());
      session.run(pixel());
      expect(spy.calls, 1);
      session.run(pixel(shadows: 20));
      expect(spy.calls, 2);
    });

    test('сессия: повторный запуск с теми же данными даёт тот же результат, смена силы пересчитывает', () {
      final ImageToGridSession session = ImageToGridSession();
      final int? first = session.run(request()).stats?.shadowPercent;
      expect(session.run(request()).stats?.shadowPercent, first);
      expect(session.run(request(shadows: 20)).stats?.shadowPercent, 20);
      expect(session.run(request(shadows: 80)).stats?.shadowPercent, 80);
    });

    test('исходная картинка запроса не изменяется', () {
      final Uint8List before = Uint8List.fromList(dark.rgba);
      const ImageToGridPipeline().run(request(shadows: 100));
      expect(dark.rgba, before);
    });
  });
}
