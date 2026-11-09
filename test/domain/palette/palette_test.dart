import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/palette/symbol_assigner.dart';
import 'package:flutter_test/flutter_test.dart';

PatternColor _color(String name, Rgb rgb, {String? symbol}) => PatternColor(
  rgb: rgb,
  name: name,
  components: <CatalogRef>[CatalogRef(brand: 'Miyuki', code: name)],
  symbol: symbol,
);

void main() {
  group('PatternColor', () {
    test('допускает 1 и 2 компонента, не 0 и не 3', () {
      const CatalogRef a = CatalogRef(brand: 'DMC', code: '310');
      const CatalogRef b = CatalogRef(brand: 'DMC', code: '413');
      const Rgb rgb = Rgb(0, 0, 0);
      expect(PatternColor(rgb: rgb, name: 'x', components: const <CatalogRef>[a]).components, hasLength(1));
      expect(PatternColor(rgb: rgb, name: 'x', components: const <CatalogRef>[a, b]).components, hasLength(2));
      expect(() => PatternColor(rgb: rgb, name: 'x', components: const <CatalogRef>[]), throwsArgumentError);
      expect(() => PatternColor(rgb: rgb, name: 'x', components: const <CatalogRef>[a, b, a]), throwsArgumentError);
    });

    test('компоненты неизменяемы снаружи', () {
      final PatternColor c = _color('a', const Rgb(1, 2, 3));
      expect(() => c.components.add(const CatalogRef(brand: 'x', code: 'y')), throwsUnsupportedError);
    });

    test('blend: RGB среднее в линейном RGB, компоненты и отделка сохраняются', () {
      final PatternColor c = PatternColor.blend(
        name: 'Блик',
        parts: const <BlendPart>[
          BlendPart(
            ref: CatalogRef(brand: 'DMC', code: '310'),
            rgb: Rgb(0, 0, 0),
          ),
          BlendPart(
            ref: CatalogRef(brand: 'DMC', code: 'BLANC'),
            rgb: Rgb(255, 255, 255),
          ),
        ],
        finish: 'blend',
      );
      expect(c.rgb, const Rgb(188, 188, 188));
      expect(c.components.map((r) => r.code), <String>['310', 'BLANC']);
      expect(c.finish, 'blend');
    });

    test('blend одной части — её цвет', () {
      final PatternColor c = PatternColor.blend(
        name: 'n',
        parts: const <BlendPart>[
          BlendPart(
            ref: CatalogRef(brand: 'a', code: 'b'),
            rgb: Rgb(9, 8, 7),
          ),
        ],
      );
      expect(c.rgb, const Rgb(9, 8, 7));
      expect(c.finish, isNull);
    });

    test('copyWith меняет только заданное', () {
      final PatternColor c = _color('a', const Rgb(1, 2, 3), symbol: 'A');
      expect(c.copyWith(name: 'b').name, 'b');
      expect(c.copyWith(name: 'b').symbol, 'A');
      expect(c.copyWith(rgb: const Rgb(4, 5, 6)).rgb, const Rgb(4, 5, 6));
      expect(c.copyWith(symbol: 'Z').symbol, 'Z');
      expect(c.copyWith(finish: 'matte').finish, 'matte');
    });
  });

  group('NearestColorMatcher', () {
    final List<(String, Rgb)> items = <(String, Rgb)>[
      ('red', const Rgb(255, 0, 0)),
      ('green', const Rgb(0, 255, 0)),
      ('blue', const Rgb(0, 0, 255)),
      ('dark-red', const Rgb(120, 0, 0)),
      ('white', const Rgb(255, 255, 255)),
    ];
    final NearestColorMatcher<(String, Rgb)> matcher = NearestColorMatcher<(String, Rgb)>(
      items,
      rgbOf: ((String, Rgb) i) => i.$2,
    );

    test('точное совпадение — первым и с нулевым ΔE', () {
      final List<ColorMatch<(String, Rgb)>> top = matcher.nearest(const Rgb(0, 0, 255), count: 1);
      expect(top.single.item.$1, 'blue');
      expect(top.single.deltaE, 0);
    });

    test('top-N отсортирован по возрастанию ΔE', () {
      final List<ColorMatch<(String, Rgb)>> top = matcher.nearest(const Rgb(200, 10, 10), count: 3);
      expect(top.map((m) => m.item.$1).first, 'red');
      expect(top, hasLength(3));
      for (int i = 1; i < top.length; i++) {
        expect(top[i].deltaE, greaterThanOrEqualTo(top[i - 1].deltaE));
      }
      expect(top[1].item.$1, 'dark-red');
    });

    test('count больше размера каталога — весь каталог; пустой каталог — пусто; count ≤ 0 — пусто', () {
      expect(matcher.nearest(const Rgb(1, 2, 3), count: 99), hasLength(5));
      expect(NearestColorMatcher<Rgb>(const <Rgb>[], rgbOf: (r) => r).nearest(const Rgb(1, 2, 3)), isEmpty);
      expect(matcher.nearest(const Rgb(1, 2, 3), count: 0), isEmpty);
    });

    test('при равном ΔE сохраняется порядок каталога', () {
      final NearestColorMatcher<int> m = NearestColorMatcher<int>(
        const <int>[1, 2],
        rgbOf: (_) => const Rgb(10, 10, 10),
      );
      expect(m.nearest(const Rgb(50, 50, 50), count: 2).map((x) => x.item), <int>[1, 2]);
    });
  });

  group('SymbolAssigner', () {
    const SymbolAssigner assigner = SymbolAssigner();

    test('начинается с A–Z, затем цифры', () {
      final List<String> first = assigner.symbols.take(36).toList();
      expect(first.take(26).join(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ');
      expect(first.skip(26).join(), '0123456789');
    });

    test('не меньше 120 различимых одиночных символов', () {
      final List<String> all = assigner.symbols;
      expect(all.length, greaterThanOrEqualTo(120));
      expect(all.toSet(), hasLength(all.length));
      expect(all.every((s) => s.runes.length == 1 && s.trim() == s), isTrue);
    });

    test('120 цветов получают 120 разных символов', () {
      final List<String?> used = <String?>[];
      for (int i = 0; i < 120; i++) {
        used.add(assigner.next(used));
      }
      expect(used.toSet(), hasLength(120));
    });

    test('стабильность: занятые не трогаем, берём первый свободный', () {
      expect(assigner.next(const <String?>[]), 'A');
      expect(assigner.next(const <String?>['A', 'B']), 'C');
      expect(assigner.next(const <String?>['A', null, 'C']), 'B');
    });

    test('внешние символы (не из набора) не мешают', () {
      expect(assigner.next(const <String?>['☃']), 'A');
    });

    test('когда символы кончились — null', () {
      expect(assigner.next(assigner.symbols), isNull);
    });
  });

  group('PaletteSnapshot', () {
    final PaletteSnapshot empty = PaletteSnapshot.empty();

    test('add присваивает символы по порядку и возвращает индекс сетки с 1', () {
      final PaletteEdit e1 = empty.add(_color('a', const Rgb(1, 1, 1))).valueOrNull!;
      final PaletteEdit e2 = e1.palette.add(_color('b', const Rgb(2, 2, 2))).valueOrNull!;
      expect(e1.gridValue, 1);
      expect(e2.gridValue, 2);
      expect(e2.palette.colors.map((c) => c.symbol), <String?>['A', 'B']);
      expect(e2.reindex.isIdentity, isTrue);
    });

    test('add сохраняет заданный символ и не допускает дубликат символа', () {
      final PaletteSnapshot p = empty.add(_color('a', const Rgb(1, 1, 1), symbol: '★')).valueOrNull!.palette;
      expect(p.colors.single.symbol, '★');
      expect(p.add(_color('b', const Rgb(2, 2, 2), symbol: '★')).failureOrNull, isA<ValidationFailure>());
    });

    test('add: символ нового цвета не повторяет занятые, символы существующих стабильны', () {
      PaletteSnapshot p = empty;
      for (int i = 0; i < 5; i++) {
        p = p.add(_color('c$i', Rgb(i, i, i))).valueOrNull!.palette;
      }
      final List<String?> before = p.colors.map((c) => c.symbol).toList();
      final PaletteSnapshot p2 = p.add(_color('new', const Rgb(9, 9, 9))).valueOrNull!.palette;
      expect(p2.colors.map((c) => c.symbol).take(5), before);
      expect(p2.colors.map((c) => c.symbol).toSet(), hasLength(6));
    });

    test('rename меняет только название', () {
      final PaletteSnapshot p = empty.add(_color('a', const Rgb(1, 1, 1))).valueOrNull!.palette;
      final PaletteEdit e = p.rename(1, 'Новое').valueOrNull!;
      expect(e.palette.colors.single.name, 'Новое');
      expect(e.palette.colors.single.rgb, const Rgb(1, 1, 1));
      expect(e.reindex.isIdentity, isTrue);
    });

    test('rename пустого названия — ValidationFailure', () {
      final PaletteSnapshot p = empty.add(_color('a', const Rgb(1, 1, 1))).valueOrNull!.palette;
      expect(p.rename(1, '  ').failureOrNull, isA<ValidationFailure>());
    });

    test('replace меняет цвет и компоненты, сохраняя символ', () {
      final PaletteSnapshot p = empty.add(_color('a', const Rgb(1, 1, 1))).valueOrNull!.palette;
      final PatternColor repl = _color('z', const Rgb(5, 5, 5), symbol: 'Q');
      final PaletteEdit e = p.replace(1, repl).valueOrNull!;
      expect(e.palette.colors.single.rgb, const Rgb(5, 5, 5));
      expect(e.palette.colors.single.symbol, 'A');
      expect(e.palette.colors.single.components.single.code, 'z');
    });

    test('remove даёт карту переиндексации: удалённый → 0, старшие сдвигаются', () {
      PaletteSnapshot p = empty;
      for (int i = 0; i < 4; i++) {
        p = p.add(_color('c$i', Rgb(i, i, i))).valueOrNull!.palette;
      }
      final PaletteEdit e = p.remove(2).valueOrNull!;
      expect(e.palette.colors.map((c) => c.name), <String>['c0', 'c2', 'c3']);
      expect(e.reindex.apply(0), 0);
      expect(e.reindex.apply(1), 1);
      expect(e.reindex.apply(2), 0);
      expect(e.reindex.apply(3), 2);
      expect(e.reindex.apply(4), 3);
      expect(e.reindex.isIdentity, isFalse);
    });

    test('remove последнего не двигает остальных', () {
      PaletteSnapshot p = empty;
      for (int i = 0; i < 3; i++) {
        p = p.add(_color('c$i', Rgb(i, i, i))).valueOrNull!.palette;
      }
      final PaletteEdit e = p.remove(3).valueOrNull!;
      expect(<int>[1, 2, 3].map(e.reindex.apply), <int>[1, 2, 0]);
    });

    test('merge: цвет вливается в другой, ячейки получают его индекс', () {
      PaletteSnapshot p = empty;
      for (int i = 0; i < 3; i++) {
        p = p.add(_color('c$i', Rgb(i, i, i))).valueOrNull!.palette;
      }
      final PaletteEdit e = p.merge(from: 1, into: 3).valueOrNull!;
      expect(e.palette.colors.map((c) => c.name), <String>['c1', 'c2']);
      expect(<int>[0, 1, 2, 3].map(e.reindex.apply), <int>[0, 2, 1, 2]);
    });

    test('merge в цвет с меньшим индексом: ячейки from получают into, старшие сдвигаются', () {
      PaletteSnapshot p = empty;
      for (int i = 0; i < 4; i++) {
        p = p.add(_color('c$i', Rgb(i, i, i))).valueOrNull!.palette;
      }
      final PaletteEdit e = p.merge(from: 3, into: 1).valueOrNull!;
      expect(e.palette.colors.map((c) => c.name), <String>['c0', 'c1', 'c3']);
      expect(<int>[0, 1, 2, 3, 4].map(e.reindex.apply), <int>[0, 1, 2, 1, 3]);
    });

    test('индекс вне палитры и merge с самим собой — ValidationFailure', () {
      final PaletteSnapshot p = empty.add(_color('a', const Rgb(1, 1, 1))).valueOrNull!.palette;
      expect(p.rename(0, 'x').failureOrNull, isA<ValidationFailure>());
      expect(p.rename(2, 'x').failureOrNull, isA<ValidationFailure>());
      expect(p.replace(2, _color('x', const Rgb(0, 0, 0))).failureOrNull, isA<ValidationFailure>());
      expect(p.remove(2).failureOrNull, isA<ValidationFailure>());
      expect(p.merge(from: 1, into: 1).failureOrNull, isA<ValidationFailure>());
      expect(p.merge(from: 1, into: 2).failureOrNull, isA<ValidationFailure>());
    });

    test('палитра не больше 65535 цветов (Uint16 в сетке)', () {
      expect(PaletteSnapshot.maxColors, 65535);
    });

    test('палитра неизменяема и сравнивается по значению', () {
      final PaletteSnapshot p = empty.add(_color('a', const Rgb(1, 1, 1))).valueOrNull!.palette;
      expect(() => p.colors.add(_color('x', const Rgb(0, 0, 0))), throwsUnsupportedError);
      expect(p, PaletteSnapshot(p.colors));
      expect(p.length, 1);
      expect(p.colorAt(1), p.colors.first);
      expect(p.colorAt(0), isNull);
    });

    test('Result — успех или Failure, а не исключение', () {
      expect(empty.remove(1), isA<Err<PaletteEdit>>());
    });
  });
}
