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
  });
}
