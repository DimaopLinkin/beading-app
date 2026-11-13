import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/palette_from_generated.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';

void main() {
  test('позиция каталога сохраняется ссылкой, цвет вне каталога — пользовательским', () {
    final GeneratedPattern pattern = GeneratedPattern(
      grid: Grid.fromCells(width: 2, height: 1, cells: const <int>[1, 2]),
      palette: <PaletteEntry>[
        PaletteEntry.fromCatalog(catalogColor('DB0010', 'Красный', '#C80A14')),
        const PaletteEntry(rgb: Rgb(1, 2, 3)),
      ],
    );
    final PaletteSnapshot palette = paletteFromGenerated(pattern).valueOrNull!;
    expect(palette.length, 2);
    expect(palette.colorAt(1)!.components, const <CatalogRef>[CatalogRef(brand: 'Miyuki', code: 'DB0010')]);
    expect(palette.colorAt(1)!.name, 'Красный');
    expect(palette.colorAt(2)!.components.single, const CatalogRef(brand: customColorBrand, code: '#010203'));
    expect(palette.colorAt(2)!.rgb, const Rgb(1, 2, 3));
  });

  test('у каждого цвета свой символ', () {
    final GeneratedPattern pattern = GeneratedPattern(
      grid: Grid.fromCells(width: 3, height: 1, cells: const <int>[1, 2, 3]),
      palette: const <PaletteEntry>[
        PaletteEntry(rgb: Rgb(1, 2, 3)),
        PaletteEntry(rgb: Rgb(4, 5, 6)),
        PaletteEntry(rgb: Rgb(7, 8, 9)),
      ],
    );
    final PaletteSnapshot palette = paletteFromGenerated(pattern).valueOrNull!;
    final Set<String?> symbols = palette.colors.map((c) => c.symbol).toSet();
    expect(symbols, hasLength(3));
    expect(symbols, isNot(contains(null)));
  });
}
