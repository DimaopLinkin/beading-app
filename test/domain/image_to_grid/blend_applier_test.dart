import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/blend_applier.dart';
import 'package:beading/domain/image_to_grid/blend_suggester.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/palette_from_generated.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogColor _floss(String code, Rgb rgb) =>
    CatalogColor(material: CatalogMaterial.floss, brand: 'DMC', series: '', code: code, name: 'DMC $code', rgb: rgb);

void main() {
  final CatalogColor red = _floss('321', const Rgb(200, 40, 40));
  final CatalogColor yellow = _floss('743', const Rgb(230, 200, 50));
  final CatalogColor blue = _floss('797', const Rgb(20, 40, 160));
  final Rgb mix = Rgb.average(<Rgb>[red.rgb, yellow.rgb]);

  GeneratedPattern pattern() => GeneratedPattern(
    grid: Grid.fromCells(width: 4, height: 2, cells: const <int>[1, 1, 2, 2, 1, 3, 2, 3]),
    palette: <PaletteEntry>[
      PaletteEntry.fromCatalog(red),
      PaletteEntry.fromCatalog(yellow),
      PaletteEntry.fromCatalog(blue),
    ],
  );

  test('клетки предложения получают цвет бленда, а опустевшая нитка уходит из палитры', () {
    final BlendSuggestion blend = BlendSuggestion(first: 0, second: 1, rgb: mix, cells: const <int>[2, 3], meanGain: 3);
    final GeneratedPattern result = applyBlends(pattern(), <BlendSuggestion>[blend]);
    expect(result.palette, hasLength(4));
    expect(result.palette.last.rgb, mix);
    expect(result.palette.last.catalog, red);
    expect(result.palette.last.blendPartner, yellow);
    expect(result.grid.cells, <int>[1, 1, 4, 4, 1, 3, 2, 3]);
  });

  test('если нитка больше нигде не нужна, её запись убирается и номера сдвигаются', () {
    final BlendSuggestion blend = BlendSuggestion(
      first: 0,
      second: 1,
      rgb: mix,
      cells: const <int>[0, 1, 2, 3, 4, 6],
      meanGain: 3,
    );
    final GeneratedPattern result = applyBlends(pattern(), <BlendSuggestion>[blend]);
    expect(result.palette.map((e) => e.blendPartner == null ? e.catalog!.code : 'blend'), <String>['797', 'blend']);
    expect(result.grid.cells, <int>[2, 2, 2, 2, 2, 1, 2, 1]);
  });

  test('бленд попадает в палитру схемы как смешанная нить из двух ссылок каталога', () {
    final BlendSuggestion blend = BlendSuggestion(first: 0, second: 1, rgb: mix, cells: const <int>[2, 3], meanGain: 3);
    final PaletteSnapshot palette = paletteFromGenerated(applyBlends(pattern(), <BlendSuggestion>[blend])).valueOrNull!;
    final blended = palette.colors.last;
    expect(blended.components.map((c) => c.code), <String>['321', '743']);
    expect(blended.rgb, mix);
  });

  test('нитки не из каталога в бленд не идут: схема не меняется', () {
    final GeneratedPattern free = GeneratedPattern(
      grid: Grid.fromCells(width: 2, height: 1, cells: const <int>[1, 2]),
      palette: const <PaletteEntry>[
        PaletteEntry(rgb: Rgb(200, 40, 40)),
        PaletteEntry(rgb: Rgb(230, 200, 50)),
      ],
    );
    final BlendSuggestion blend = BlendSuggestion(first: 0, second: 1, rgb: mix, cells: const <int>[0], meanGain: 3);
    expect(identical(applyBlends(free, <BlendSuggestion>[blend]), free), isTrue);
  });
}
