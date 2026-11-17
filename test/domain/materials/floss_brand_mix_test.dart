import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/materials/floss_brand_mix.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogRef _ref(String brand, String code) => CatalogRef(brand: brand, code: code);

PatternColor _color(CatalogRef ref) =>
    PatternColor(rgb: const Rgb(10, 20, 30), name: ref.code, components: <CatalogRef>[ref]);

void main() {
  group('FlossBrandMix', () {
    test('один бренд или пусто: сводки нет', () {
      expect(FlossBrandMix.of(const <CatalogRef>[]), isNull);
      expect(FlossBrandMix.of(<CatalogRef>[_ref('DMC', '310'), _ref('DMC', '666')]), isNull);
    });

    test('основной бренд — где ниток больше; остальные по убыванию числа ниток', () {
      final FlossBrandMix mix = FlossBrandMix.of(<CatalogRef>[
        _ref('DMC', '1'),
        _ref('DMC', '2'),
        _ref('DMC', '3'),
        _ref('DMC', '3'),
        _ref('Гамма', '10'),
        _ref('Anchor', '5'),
        _ref('Anchor', '6'),
      ])!;
      expect(mix.main, 'DMC');
      expect(mix.foreignBrands, <String>['Anchor', 'Гамма']);
      expect(mix.foreignThreads, 3);
    });

    test('при равенстве основной — первый по алфавиту', () {
      final FlossBrandMix mix = FlossBrandMix.of(<CatalogRef>[_ref('DMC', '1'), _ref('Anchor', '2')])!;
      expect(mix.main, 'Anchor');
      expect(mix.foreign, <String, int>{'DMC': 1});
    });
  });

  test('FlossEstimate.brandMix считает бренды списка покупок', () {
    FlossEstimate estimate(List<CatalogRef> refs) =>
        FlossEstimator(
          fabric: Fabric.standard,
          layers: StitchLayers.empty(columns: refs.length, rows: 1),
          reserve: 0,
        ).estimate(
          Grid.fromCells(width: refs.length, height: 1, cells: <int>[for (int i = 1; i <= refs.length; i++) i]),
          PaletteSnapshot(<PatternColor>[for (final CatalogRef r in refs) _color(r)]),
        );

    expect(estimate(<CatalogRef>[_ref('DMC', '310'), _ref('DMC', '666')]).brandMix, isNull);
    final FlossBrandMix? mix = estimate(<CatalogRef>[
      _ref('DMC', '310'),
      _ref('DMC', '666'),
      _ref('Anchor', '1088'),
    ]).brandMix;
    expect(mix!.main, 'DMC');
    expect(mix.foreign, <String, int>{'Anchor': 1});
  });
}
