import 'package:beading/core/failure.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/palette/symbol_assigner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('значения сравниваются по содержимому и печатаются', () {
    expect(const CatalogRef(brand: 'DMC', code: '310'), const CatalogRef(brand: 'DMC', code: '310'));
    expect(const CatalogRef(brand: 'DMC', code: '310').toString(), 'DMC 310');
    expect(const Lab(1, 2, 3), const Lab(1, 2, 3));
    expect(const Lab(1, 2, 3).toString(), 'Lab(1.0, 2.0, 3.0)');
    expect(const Rgb(1, 2, 3).toString(), 'Rgb(#010203)');
    expect(const ColorMatch<int>(1, 0.5), const ColorMatch<int>(1, 0.5));
    const BlendPart part = BlendPart(
      ref: CatalogRef(brand: 'a', code: 'b'),
      rgb: Rgb(1, 2, 3),
    );
    expect(
      part,
      const BlendPart(
        ref: CatalogRef(brand: 'a', code: 'b'),
        rgb: Rgb(1, 2, 3),
      ),
    );
    final PatternColor c = PatternColor(rgb: const Rgb(1, 2, 3), name: 'n', components: <CatalogRef>[part.ref]);
    expect(c, PatternColor(rgb: const Rgb(1, 2, 3), name: 'n', components: <CatalogRef>[part.ref]));
    expect(c.props, isNotEmpty);
  });

  test('среднее очень тёмных цветов (низкая ветка гаммы)', () {
    expect(Rgb.average(const <Rgb>[Rgb(0, 0, 0), Rgb(2, 2, 2)]), const Rgb(1, 1, 1));
  });

  test('карта переиндексации и правка сравниваются по значению', () {
    final PaletteEdit a = PaletteSnapshot.empty()
        .add(
          PatternColor(
            rgb: const Rgb(0, 0, 0),
            name: 'a',
            components: const <CatalogRef>[CatalogRef(brand: 'b', code: 'c')],
          ),
        )
        .valueOrNull!;
    final PaletteEdit again = PaletteSnapshot.empty()
        .add(
          PatternColor(
            rgb: const Rgb(0, 0, 0),
            name: 'a',
            components: const <CatalogRef>[CatalogRef(brand: 'b', code: 'c')],
          ),
        )
        .valueOrNull!;
    expect(a, again);
    expect(PaletteReindex(const <int, int>{1: 0}), PaletteReindex(const <int, int>{1: 0}));
    expect(PaletteReindex(const <int, int>{1: 0}).changes, const <int, int>{1: 0});
  });

  test('палитра переполняется на maxColors и на исчерпании символов', () {
    final List<PatternColor> many = <PatternColor>[
      for (int i = 0; i < PaletteSnapshot.maxColors; i++)
        PatternColor(
          rgb: const Rgb(0, 0, 0),
          name: 'c$i',
          components: const <CatalogRef>[CatalogRef(brand: 'b', code: 'c')],
          symbol: 's$i',
        ),
    ];
    expect(
      PaletteSnapshot(many)
          .add(
            PatternColor(
              rgb: const Rgb(0, 0, 0),
              name: 'x',
              components: const <CatalogRef>[CatalogRef(brand: 'b', code: 'c')],
            ),
          )
          .isFailure,
      isTrue,
    );
    final PaletteSnapshot full = PaletteSnapshot(<PatternColor>[
      for (final String s in const SymbolAssigner().symbols)
        PatternColor(
          rgb: const Rgb(0, 0, 0),
          name: s,
          components: const <CatalogRef>[CatalogRef(brand: 'b', code: 'c')],
          symbol: s,
        ),
    ]);
    expect(
      full
          .add(
            PatternColor(
              rgb: const Rgb(0, 0, 0),
              name: 'x',
              components: const <CatalogRef>[CatalogRef(brand: 'b', code: 'c')],
            ),
          )
          .failureOrNull,
      isA<ValidationFailure>(),
    );
  });
}
