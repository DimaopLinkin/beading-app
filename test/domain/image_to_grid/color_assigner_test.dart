import 'package:beading/domain/image_to_grid/color_assigner.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ColorAssigner assigner = ColorAssigner();
  const Rgb black = Rgb(0, 0, 0);
  const Rgb white = Rgb(255, 255, 255);
  const Rgb red = Rgb(255, 0, 0);

  group('ColorAssigner', () {
    test('каждой ячейке — ближайший цвет палитры, пустые остаются нулём', () {
      final List<int> result = assigner.assign(
        cells: <Rgb?>[const Rgb(10, 10, 10), const Rgb(240, 240, 240), null, const Rgb(250, 20, 10)],
        columns: 2,
        rows: 2,
        palette: <Rgb>[black, white, red],
      );

      expect(result, <int>[1, 2, 0, 3]);
    });

    test('пустая палитра — все нули', () {
      final List<int> result = assigner.assign(cells: <Rgb?>[white], columns: 1, rows: 1, palette: <Rgb>[]);

      expect(result, <int>[0]);
    });

    test('без дизеринга серый целиком уходит в один цвет', () {
      final List<int> result = assigner.assign(
        cells: List<Rgb?>.filled(16, const Rgb(119, 119, 119)),
        columns: 4,
        rows: 4,
        palette: <Rgb>[black, white],
      );

      expect(result.toSet(), hasLength(1));
    });

    test('дизеринг смешивает чёрный и белый: средний серый даёт примерно половину тех и других', () {
      final List<int> result = assigner.assign(
        cells: List<Rgb?>.filled(100, const Rgb(119, 119, 119)),
        columns: 10,
        rows: 10,
        palette: <Rgb>[black, white],
        dither: true,
      );

      final int blacks = result.where((v) => v == 1).length;
      expect(blacks, inInclusiveRange(40, 60));
    });

    test('дизеринг детерминирован и не трогает пустые ячейки', () {
      final List<Rgb?> cells = <Rgb?>[for (int i = 0; i < 25; i++) i == 12 ? null : const Rgb(100, 100, 100)];

      final List<int> a = assigner.assign(
        cells: cells,
        columns: 5,
        rows: 5,
        palette: <Rgb>[black, white],
        dither: true,
      );
      final List<int> b = assigner.assign(
        cells: cells,
        columns: 5,
        rows: 5,
        palette: <Rgb>[black, white],
        dither: true,
      );

      expect(a, b);
      expect(a[12], 0);
    });

    test('дизеринг не меняет точные цвета палитры', () {
      final List<int> result = assigner.assign(
        cells: <Rgb?>[black, white, white, black],
        columns: 2,
        rows: 2,
        palette: <Rgb>[black, white],
        dither: true,
      );

      expect(result, <int>[1, 2, 2, 1]);
    });

    group('тёплая клетка не уходит в серую нитку (T74)', () {
      // Затенённый лоб с фото и нитки «Гаммы»: серо-бежевая 3035 по ΔE2000 ближе всех (3,3), но рядом с тёплой кожей
      // читается тёмным грязным пятном. Тёплая 0807 той же светлоты и насыщенности (ΔE2000 6,0), 5202 светлее (7,1).
      const Rgb shadedSkin = Rgb(173, 135, 101);
      const Rgb grey3035 = Rgb(0xa4, 0x86, 0x6c);
      const Rgb warm0807 = Rgb(0xa4, 0x7d, 0x4b);
      const Rgb light5202 = Rgb(0xc9, 0x9a, 0x76);

      test('кожа в тени берёт тёплую нитку, а не серую', () {
        final List<int> result = assigner.assign(
          cells: <Rgb?>[shadedSkin],
          columns: 1,
          rows: 1,
          palette: <Rgb>[grey3035, warm0807, light5202],
        );
        expect(result, <int>[2]);
      });

      test('серая клетка серую нитку берёт как раньше', () {
        final List<int> result = assigner.assign(
          cells: <Rgb?>[grey3035],
          columns: 1,
          rows: 1,
          palette: <Rgb>[grey3035, warm0807, light5202],
        );
        expect(result, <int>[1]);
      });

      test('если тёплой нитки близко нет, серая остаётся лучшей', () {
        final List<int> result = assigner.assign(
          cells: <Rgb?>[shadedSkin],
          columns: 1,
          rows: 1,
          palette: <Rgb>[grey3035, const Rgb(230, 120, 20)],
        );
        expect(result, <int>[1]);
      });

      test('без надбавки (chromaPenalty: 0) — чистый ΔE2000, как до T74', () {
        final List<int> result = const ColorAssigner(chromaPenalty: 0).assign(
          cells: <Rgb?>[shadedSkin],
          columns: 1,
          rows: 1,
          palette: <Rgb>[grey3035, warm0807, light5202],
        );
        expect(result, <int>[1]);
      });
    });
  });
}
