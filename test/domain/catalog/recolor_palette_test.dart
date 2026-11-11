import 'package:beading/core/failure.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/use_cases/recolor_palette.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';

void main() {
  CatalogColor dmc(String code, String hex, [String name = 'n']) => catalogColor(
    code,
    '$name $code',
    hex,
    brand: 'DMC',
    series: 'Mouliné',
    material: CatalogMaterial.floss,
  );
  CatalogColor anchor(String code, String hex) =>
      catalogColor(code, 'A $code', hex, brand: 'Anchor', series: 'Mouliné', material: CatalogMaterial.floss);

  final CatalogColor dmcRed = dmc('321', '#cc0000');
  final CatalogColor dmcBlue = dmc('797', '#0000cc');
  final CatalogColor anchorRed = anchor('9046', '#cb0202');
  final CatalogColor anchorFarRed = anchor('1', '#990000');
  final CatalogColor anchorBlue = anchor('132', '#0101cd');

  late FakeCatalogRepository catalog;
  setUp(() => catalog = FakeCatalogRepository(<CatalogColor>[dmcRed, dmcBlue, anchorRed, anchorFarRed, anchorBlue]));

  PatternColor of(CatalogColor c, {String? symbol}) =>
      PatternColor(rgb: c.rgb, name: c.name, components: <CatalogRef>[c.ref], symbol: symbol);

  test('каждый цвет заменяется ближайшим по ΔE2000 в выбранном бренде, символы и порядок сохраняются', () async {
    final PaletteSnapshot palette = PaletteSnapshot(<PatternColor>[of(dmcRed, symbol: 'A'), of(dmcBlue, symbol: 'B')]);

    final RecolorResult result = (await RecolorPalette(catalog)(palette, brand: 'Anchor')).valueOrNull!;

    expect(result.palette.colors.map((c) => c.components.single), <CatalogRef>[anchorRed.ref, anchorBlue.ref]);
    expect(result.palette.colors.map((c) => c.symbol), <String?>['A', 'B']);
    expect(result.palette.colors.map((c) => c.rgb), <Rgb>[anchorRed.rgb, anchorBlue.rgb]);
    expect(result.palette.colors.first.name, anchorRed.name);
    expect(result.matches.map((m) => m.deltaE), everyElement(lessThan(2)));
  });

  test('смешанная нить: каждая нитка заменяется отдельно, цвет — среднее новых', () async {
    final PatternColor blend = PatternColor.blend(
      name: 'mix',
      parts: <BlendPart>[
        BlendPart(ref: dmcRed.ref, rgb: dmcRed.rgb),
        BlendPart(ref: dmcBlue.ref, rgb: dmcBlue.rgb),
      ],
    );

    final RecolorResult result = (await RecolorPalette(catalog)(
      PaletteSnapshot(<PatternColor>[blend]),
      brand: 'Anchor',
    )).valueOrNull!;

    final PatternColor out = result.palette.colors.single;
    expect(out.components, <CatalogRef>[anchorRed.ref, anchorBlue.ref]);
    expect(out.rgb, Rgb.average(<Rgb>[anchorRed.rgb, anchorBlue.rgb]));
  });

  test('цвет не из каталога (свой) подбирается по своему RGB', () async {
    final PatternColor custom = PatternColor(
      rgb: const Rgb(0xcb, 0x00, 0x00),
      name: 'свой',
      components: const <CatalogRef>[CatalogRef(brand: 'Мой', code: '1')],
    );

    final RecolorResult result = (await RecolorPalette(catalog)(
      PaletteSnapshot(<PatternColor>[custom]),
      brand: 'Anchor',
    )).valueOrNull!;

    expect(result.palette.colors.single.components.single, anchorRed.ref);
  });

  test('смесь из двух ниток, ушедших в одну позицию, остаётся смесью двух одинаковых ссылок', () async {
    final PatternColor blend = PatternColor.blend(
      name: 'mix',
      parts: <BlendPart>[
        BlendPart(ref: dmcRed.ref, rgb: dmcRed.rgb),
        BlendPart(ref: anchorFarRed.ref, rgb: anchorFarRed.rgb),
      ],
    );
    final FakeCatalogRepository only = FakeCatalogRepository(<CatalogColor>[dmcRed, anchorRed, anchorFarRed]);

    final RecolorResult result = (await RecolorPalette(only)(
      PaletteSnapshot(<PatternColor>[blend]),
      brand: 'Anchor',
    )).valueOrNull!;

    expect(result.palette.colors.single.components, hasLength(2));
    expect(result.matches.single.to, <CatalogRef>[anchorRed.ref, anchorFarRed.ref]);
  });

  test('бисер пересчитывается только среди выбранного материала; нет такого бренда в материале — ошибка', () async {
    final PaletteSnapshot palette = PaletteSnapshot(<PatternColor>[of(dmcRed)]);

    final result = await RecolorPalette(catalog, material: CatalogMaterial.bead)(palette, brand: 'Anchor');

    expect(result.failureOrNull, isA<ValidationFailure>());
  });

  test('ссылка на позицию, которой нет в каталоге, подбирается по RGB цвета палитры', () async {
    final PatternColor orphan = PatternColor(
      rgb: anchorBlue.rgb,
      name: 'сирота',
      components: const <CatalogRef>[CatalogRef(brand: 'DMC', code: 'снят')],
    );

    final RecolorResult result = (await RecolorPalette(catalog)(
      PaletteSnapshot(<PatternColor>[orphan]),
      brand: 'Anchor',
    )).valueOrNull!;

    expect(result.palette.colors.single.components.single, anchorBlue.ref);
  });

  test('пересчёт в тот же бренд ничего не меняет, ΔE = 0', () async {
    final PaletteSnapshot palette = PaletteSnapshot(<PatternColor>[of(dmcRed, symbol: 'A')]);

    final RecolorResult result = (await RecolorPalette(catalog)(palette, brand: 'DMC')).valueOrNull!;

    expect(result.palette.colors.single.components, <CatalogRef>[dmcRed.ref]);
    expect(result.matches.single.deltaE, 0);
  });

  test('отчёт: для каждого цвета старая и новая позиция и ΔE; maxDeltaE — худшее', () async {
    final RecolorResult result = (await RecolorPalette(catalog)(
      PaletteSnapshot(<PatternColor>[of(dmcRed), of(dmcBlue)]),
      brand: 'Anchor',
    )).valueOrNull!;

    expect(result.matches.map((m) => m.index), <int>[0, 1]);
    expect(result.matches.first.from, <CatalogRef>[dmcRed.ref]);
    expect(result.matches.first.to, <CatalogRef>[anchorRed.ref]);
    expect(result.maxDeltaE, result.matches.map((m) => m.deltaE).reduce((a, b) => a > b ? a : b));
  });

  test('нет такого бренда в каталоге — ValidationFailure, палитра не тронута', () async {
    final Object? failure = (await RecolorPalette(catalog)(
      PaletteSnapshot(<PatternColor>[of(dmcRed)]),
      brand: 'Madeira',
    )).failureOrNull;

    expect(failure, isA<ValidationFailure>());
  });

  test('ошибка хранилища передаётся наверх', () async {
    catalog.fail = true;

    final result = await RecolorPalette(catalog)(PaletteSnapshot(<PatternColor>[of(dmcRed)]), brand: 'Anchor');

    expect(result.failureOrNull, isA<StorageFailure>());
  });

  test('пустая палитра остаётся пустой', () async {
    final RecolorResult result = (await RecolorPalette(catalog)(PaletteSnapshot.empty(), brand: 'Anchor')).valueOrNull!;

    expect(result.palette.length, 0);
    expect(result.maxDeltaE, 0);
  });
}
