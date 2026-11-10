import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/pattern_generation/pattern_generator.dart';
import 'package:beading/domain/pattern_generation/pattern_template.dart';
import 'package:flutter_test/flutter_test.dart';

PatternColor _c(String code, Rgb rgb) => PatternColor(
  rgb: rgb,
  name: code,
  components: <CatalogRef>[CatalogRef(brand: 'T', code: code)],
);

final PatternColor _a = _c('a', const Rgb(200, 30, 30));
final PatternColor _b = _c('b', const Rgb(30, 30, 200));
final PatternColor _g = _c('g', const Rgb(30, 160, 30));
const PatternGenerator _gen = PatternGenerator();

/// Сетка в виде строк «0101», по рядам.
List<String> _rows(Grid grid) => <String>[
  for (int r = 0; r < grid.height; r++) <int>[for (int c = 0; c < grid.width; c++) grid.at(c, r) - 1].join(),
];

GeneratedPattern _ok(Result<GeneratedPattern> r) => (r as Success<GeneratedPattern>).value;

GeneratedPattern _make(
  PatternTemplate t,
  int w,
  int h, {
  List<PatternColor>? colors,
  GridGeometry geometry = const GridGeometry.rectangular(),
  PatternSymmetry symmetry = PatternSymmetry.none,
}) => _ok(
  _gen.generate(
    template: t,
    colors: colors ?? <PatternColor>[_a, _b],
    width: w,
    height: h,
    geometry: geometry,
    symmetry: symmetry,
  ),
);

/// Серый каталог с шагом 5 по каждому каналу.
List<PatternColor> _greys() => <PatternColor>[
  for (int v = 0; v <= 255; v += 5) _c('g$v', Rgb(v, v, v)),
];

void main() {
  group('полосы', () {
    test('горизонтальные полосы по 2 ряда, три цвета по кругу', () {
      final GeneratedPattern p = _make(const StripesTemplate(), 3, 8, colors: <PatternColor>[_a, _b, _g]);
      expect(_rows(p.grid), <String>['000', '000', '111', '111', '222', '222', '000', '000']);
      expect(p.palette, <PatternColor>[_a, _b, _g]);
    });

    test('вертикальные полосы шириной 1', () {
      final GeneratedPattern p = _make(const StripesTemplate(stripeWidth: 1, axis: PatternAxis.x), 5, 2);
      expect(_rows(p.grid), <String>['01010', '01010']);
    });
  });

  test('зигзаг: амплитуда 2, линия 1, просвет 1', () {
    final GeneratedPattern p = _make(const ZigzagTemplate(amplitude: 2, gap: 1), 4, 4);
    expect(_rows(p.grid), <String>['1000', '0101', '0010', '0000']);
  });

  test('ромбы размера 2', () {
    final GeneratedPattern p = _make(const DiamondsTemplate(size: 2), 8, 4);
    expect(_rows(p.grid), <String>['00000000', '01100110', '01100110', '00000000']);
  });

  test('шахматка 2×2', () {
    final GeneratedPattern p = _make(const CheckerTemplate(), 6, 4);
    expect(_rows(p.grid), <String>['001100', '001100', '110011', '110011']);
  });

  test('бордюр толщиной 1 и 2', () {
    expect(_rows(_make(const BorderTemplate(thickness: 1), 5, 4).grid), <String>[
      '00000',
      '01110',
      '01110',
      '00000',
    ]);
    expect(_rows(_make(const BorderTemplate(), 6, 6).grid), <String>[
      '000000',
      '000000',
      '001100',
      '001100',
      '000000',
      '000000',
    ]);
  });

  group('градиент', () {
    final PatternColor black = _c('black', const Rgb(0, 0, 0));
    final PatternColor white = _c('white', const Rgb(255, 255, 255));

    GeneratedPattern gradient({PatternAxis axis = PatternAxis.x, int steps = 8, int w = 16, int h = 2}) => _ok(
      _gen.generate(
        template: GradientTemplate(steps: steps, axis: axis),
        colors: <PatternColor>[white, black],
        width: w,
        height: h,
        catalog: _greys(),
      ),
    );

    test('палитра от белого к чёрному, L строго убывает, концы исходные', () {
      final GeneratedPattern p = gradient();
      final List<double> ls = <double>[for (final PatternColor c in p.palette) Lab.fromRgb(c.rgb).l];
      expect(p.palette.first, white);
      expect(p.palette.last, black);
      expect(p.palette.length, greaterThan(2));
      for (int i = 1; i < ls.length; i++) {
        expect(ls[i], lessThan(ls[i - 1]));
      }
    });

    test('индексы в сетке не убывают слева направо и покрывают всю палитру', () {
      final GeneratedPattern p = gradient();
      final List<int> row = <int>[for (int c = 0; c < 16; c++) p.grid.at(c, 0)];
      for (int i = 1; i < row.length; i++) {
        expect(row[i], greaterThanOrEqualTo(row[i - 1]));
      }
      expect(row.first, 1);
      expect(row.last, p.palette.length);
      expect(p.grid.at(3, 0), p.grid.at(3, 1));
    });

    test('вертикальный градиент меняется по рядам', () {
      final GeneratedPattern p = gradient(axis: PatternAxis.y, w: 2, h: 16);
      expect(p.grid.at(0, 0), 1);
      expect(p.grid.at(0, 15), p.palette.length);
      expect(p.grid.at(1, 7), p.grid.at(0, 7));
    });

    test('градиент от тёмного к светлому тоже монотонен', () {
      final GeneratedPattern p = _ok(
        _gen.generate(
          template: const GradientTemplate(),
          colors: <PatternColor>[black, white],
          width: 10,
          height: 1,
          catalog: _greys(),
        ),
      );
      final List<double> ls = <double>[for (final PatternColor c in p.palette) Lab.fromRgb(c.rgb).l];
      for (int i = 1; i < ls.length; i++) {
        expect(ls[i], greaterThan(ls[i - 1]));
      }
    });

    test('бедный каталог даёт меньше ступеней, а не повторы', () {
      final GeneratedPattern p = _ok(
        _gen.generate(
          template: const GradientTemplate(steps: 10),
          colors: <PatternColor>[white, black],
          width: 10,
          height: 1,
          catalog: <PatternColor>[white, black, _c('mid', const Rgb(119, 119, 119))],
        ),
      );
      expect(p.palette, hasLength(3));
      expect(p.palette.toSet(), hasLength(3));
    });

    test('без каталога — ошибка валидации', () {
      final Result<GeneratedPattern> r = _gen.generate(
        template: const GradientTemplate(),
        colors: <PatternColor>[white, black],
        width: 4,
        height: 4,
      );
      expect(r.failureOrNull, isA<ValidationFailure>());
    });
  });

  group('Lab.toRgb', () {
    test('обратное к fromRgb на сетке цветов', () {
      for (final int r in <int>[0, 40, 128, 255]) {
        for (final int g in <int>[0, 90, 255]) {
          for (final int b in <int>[0, 17, 200, 255]) {
            final Rgb rgb = Rgb(r, g, b);
            final Rgb back = Lab.fromRgb(rgb).toRgb();
            expect((back.r - r).abs(), lessThanOrEqualTo(1), reason: '$rgb → $back');
            expect((back.g - g).abs(), lessThanOrEqualTo(1), reason: '$rgb → $back');
            expect((back.b - b).abs(), lessThanOrEqualTo(1), reason: '$rgb → $back');
          }
        }
      }
    });

    test('lerp на концах и в середине', () {
      const Lab x = Lab(0, 0, 0);
      const Lab y = Lab(100, 20, -40);
      expect(Lab.lerp(x, y, 0), x);
      expect(Lab.lerp(x, y, 1), y);
      expect(Lab.lerp(x, y, 0.5), const Lab(50, 10, -20));
    });
  });

  group('симметрия', () {
    final List<PatternTemplate> templates = <PatternTemplate>[
      const ZigzagTemplate(),
      const DiamondsTemplate(),
      const CheckerTemplate(),
      const StripesTemplate(axis: PatternAxis.x),
    ];

    for (final PatternTemplate t in templates) {
      for (final (int w, int h) in <(int, int)>[(9, 7), (10, 8)]) {
        test('${t.runtimeType} $w×$h: both симметричен по обеим осям', () {
          final Grid g = _make(t, w, h, symmetry: PatternSymmetry.both).grid;
          for (int r = 0; r < h; r++) {
            for (int c = 0; c < w; c++) {
              expect(g.at(c, r), g.at(w - 1 - c, r));
              expect(g.at(c, r), g.at(c, h - 1 - r));
            }
          }
        });
      }
    }

    test('horizontal не трогает вертикаль, левая половина сохраняется', () {
      final Grid plain = _make(const ZigzagTemplate(), 9, 7).grid;
      final Grid mirrored = _make(const ZigzagTemplate(), 9, 7, symmetry: PatternSymmetry.horizontal).grid;
      for (int r = 0; r < 7; r++) {
        for (int c = 0; c < 5; c++) {
          expect(mirrored.at(c, r), plain.at(c, r));
        }
        for (int c = 0; c < 9; c++) {
          expect(mirrored.at(c, r), mirrored.at(8 - c, r));
        }
      }
    });
  });

  group('раппорт', () {
    final List<(String, PatternTemplate, List<PatternColor>)> periodic =
        <(String, PatternTemplate, List<PatternColor>)>[
          ('полосы', const StripesTemplate(), <PatternColor>[_a, _b, _g]),
          ('вертикальные полосы', const StripesTemplate(stripeWidth: 3, axis: PatternAxis.x), <PatternColor>[_a, _b]),
          ('зигзаг', const ZigzagTemplate(), <PatternColor>[_a, _b]),
          ('ромбы', const DiamondsTemplate(), <PatternColor>[_a, _b]),
          ('шахматка', const CheckerTemplate(cellSize: 3), <PatternColor>[_a, _b]),
        ];
    final List<(String, GridGeometry)> geometries = <(String, GridGeometry)>[
      ('прямоугольная', const GridGeometry.rectangular()),
      ('пейот', const GridGeometry.peyote()),
      ('2-drop', const GridGeometry.peyote(drop: 2)),
      ('кирпич', const GridGeometry.brick()),
    ];

    for (final (String name, PatternTemplate t, List<PatternColor> colors) in periodic) {
      for (final (String gName, GridGeometry geometry) in geometries) {
        test('$name, $gName: узор в 3 раппорта равен повтору фрагмента', () {
          final Grid tile = _ok(_gen.generateRapport(template: t, colors: colors, geometry: geometry)).grid;
          final Grid full = _ok(
            _gen.generate(
              template: t,
              colors: colors,
              width: tile.width * 3 + 1,
              height: tile.height * 3 + 1,
              geometry: geometry,
            ),
          ).grid;
          final Grid repeated =
              (PatternGenerator.repeatTile(tile, width: full.width, height: full.height) as Success<Grid>).value;
          expect(full, repeated);
        });
      }
    }

    test('градиент и бордюр раппорта не имеют', () {
      expect(
        _gen.generateRapport(template: const BorderTemplate(), colors: <PatternColor>[_a, _b]).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        _gen.generateRapport(template: const GradientTemplate(), colors: <PatternColor>[_a, _b]).failureOrNull,
        isA<ValidationFailure>(),
      );
    });

    test('repeatTile проверяет размер', () {
      final Grid tile = Grid.fromCells(width: 1, height: 1, cells: const <int>[1]);
      expect(PatternGenerator.repeatTile(tile, width: 0, height: 3).failureOrNull, isA<ValidationFailure>());
    });
  });

  group('геометрия', () {
    test('пейот: у сдвинутых столбцов ромб начинается на полячейки раньше', () {
      final Grid rect = _make(const DiamondsTemplate(size: 2), 4, 4).grid;
      final Grid peyote = _make(
        const DiamondsTemplate(size: 2),
        4,
        4,
        geometry: const GridGeometry.peyote(),
      ).grid;
      expect(rect.at(1, 0), 1);
      expect(peyote.at(1, 0), 2);
      // Несдвинутые столбцы совпадают с прямоугольной геометрией.
      for (int r = 0; r < 4; r++) {
        expect(peyote.at(0, r), rect.at(0, r));
        expect(peyote.at(2, r), rect.at(2, r));
      }
    });

    test('кирпич: шахматка 1×1 в сдвинутом ряду сдвигается на ячейку', () {
      final Grid g = _make(const CheckerTemplate(cellSize: 1), 4, 2, geometry: const GridGeometry.brick()).grid;
      expect(_rows(g), <String>['0101', '1010']);
    });
  });

  group('проверка входа', () {
    test('неверные параметры шаблонов', () {
      for (final PatternTemplate t in <PatternTemplate>[
        const StripesTemplate(stripeWidth: 0),
        const ZigzagTemplate(amplitude: 0),
        const ZigzagTemplate(thickness: 0),
        const ZigzagTemplate(gap: -1),
        const DiamondsTemplate(size: 0),
        const CheckerTemplate(cellSize: 0),
        const BorderTemplate(thickness: 0),
        const GradientTemplate(steps: 1),
        const GradientTemplate(steps: 65),
      ]) {
        expect(
          _gen
              .generate(template: t, colors: <PatternColor>[_a, _b], width: 4, height: 4, catalog: _greys())
              .failureOrNull,
          isA<ValidationFailure>(),
          reason: '${t.runtimeType}',
        );
      }
    });

    test('число цветов и размер', () {
      expect(
        _gen.generate(template: const CheckerTemplate(), colors: <PatternColor>[_a], width: 4, height: 4).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        _gen
            .generate(template: const CheckerTemplate(), colors: <PatternColor>[_a, _b, _g], width: 4, height: 4)
            .failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        _gen.generate(template: const StripesTemplate(), colors: <PatternColor>[_a], width: 4, height: 4).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        _gen
            .generate(template: const CheckerTemplate(), colors: <PatternColor>[_a, _b], width: 0, height: 4)
            .failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        _gen
            .generate(template: const CheckerTemplate(), colors: <PatternColor>[_a, _b], width: 4, height: 5000)
            .failureOrNull,
        isA<ValidationFailure>(),
      );
    });

    test('палитра результата неизменяема', () {
      final GeneratedPattern p = _make(const CheckerTemplate(), 2, 2);
      expect(() => p.palette.add(_g), throwsUnsupportedError);
    });
  });
}
