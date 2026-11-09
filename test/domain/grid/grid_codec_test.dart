import 'dart:math';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_codec.dart';
import 'package:flutter_test/flutter_test.dart';

Grid _decodeOrFail(Uint8List bytes) {
  final Grid? grid = GridCodec.decode(bytes).valueOrNull;
  expect(grid, isNotNull);
  return grid!;
}

void main() {
  group('GridCodec', () {
    test('первый байт — версия формата', () {
      final Uint8List bytes = GridCodec.encode(Grid.empty(width: 2, height: 2));

      expect(bytes.first, GridCodec.version);
      expect(GridCodec.version, 1);
    });

    test('пустая сетка 1×1 туда и обратно', () {
      final Grid grid = Grid.empty(width: 1, height: 1);

      expect(_decodeOrFail(GridCodec.encode(grid)), grid);
    });

    test('сетка с разными значениями туда и обратно', () {
      final Grid grid = Grid.fromCells(width: 3, height: 2, cells: <int>[0, 0, 5, 5, 5, 65535]);

      expect(_decodeOrFail(GridCodec.encode(grid)), grid);
    });

    test('однородная сетка 100×400 сжимается в несколько байт', () {
      final Uint8List bytes = GridCodec.encode(Grid.empty(width: 100, height: 400));

      expect(bytes.length, lessThan(20));
    });

    test('длинная серия счётчиком больше одного байта', () {
      final Grid grid = Grid.empty(width: 1000, height: 1000);

      expect(_decodeOrFail(GridCodec.encode(grid)), grid);
    });

    test('property: decode(encode(g)) == g на случайных сетках', () {
      final Random random = Random(20261109);
      for (int iteration = 0; iteration < 300; iteration++) {
        final int width = 1 + random.nextInt(40);
        final int height = 1 + random.nextInt(40);
        final int paletteSize = 1 + random.nextInt(6);
        final List<int> cells = <int>[];
        while (cells.length < width * height) {
          final int value = random.nextInt(5) == 0 ? random.nextInt(65536) : random.nextInt(paletteSize);
          final int run = 1 + random.nextInt(8);
          for (int i = 0; i < run && cells.length < width * height; i++) {
            cells.add(value);
          }
        }
        final Grid grid = Grid.fromCells(width: width, height: height, cells: cells);

        expect(_decodeOrFail(GridCodec.encode(grid)), grid, reason: 'iteration $iteration');
      }
    });

    test('неизвестная версия — ValidationFailure', () {
      final Uint8List bytes = GridCodec.encode(Grid.empty(width: 2, height: 2));
      bytes[0] = 2;

      final Failure? failure = GridCodec.decode(bytes).failureOrNull;

      expect(failure, isA<ValidationFailure>());
    });

    test('пустые данные — ValidationFailure', () {
      expect(GridCodec.decode(Uint8List(0)).failureOrNull, isA<ValidationFailure>());
    });

    test('обрезанные данные на любой длине — ValidationFailure, не исключение', () {
      final Uint8List bytes = GridCodec.encode(
        Grid.fromCells(width: 3, height: 2, cells: <int>[1, 1, 2, 3, 3, 3]),
      );

      for (int length = 0; length < bytes.length; length++) {
        final Failure? failure = GridCodec.decode(Uint8List.sublistView(bytes, 0, length)).failureOrNull;
        expect(failure, isA<ValidationFailure>(), reason: 'length $length');
      }
    });

    test('серии длиннее сетки — ValidationFailure', () {
      final Uint8List bytes = GridCodec.encode(Grid.empty(width: 2, height: 2));
      final Uint8List shrunk = Uint8List.fromList(bytes)
        ..[1] =
            1 // ширина 1: сетка 1×2, а серия на 4 клетки
        ..[2] = 0;

      expect(GridCodec.decode(shrunk).failureOrNull, isA<ValidationFailure>());
    });

    test('серии короче сетки — ValidationFailure', () {
      final Uint8List bytes = GridCodec.encode(Grid.empty(width: 2, height: 2));
      final Uint8List grown = Uint8List.fromList(bytes)..[1] = 3;

      expect(GridCodec.decode(grown).failureOrNull, isA<ValidationFailure>());
    });

    test('нулевой размер в заголовке — ValidationFailure', () {
      final Uint8List bytes = GridCodec.encode(Grid.empty(width: 2, height: 2));
      final Uint8List zeroWidth = Uint8List.fromList(bytes)
        ..[1] = 0
        ..[2] = 0;

      expect(GridCodec.decode(zeroWidth).failureOrNull, isA<ValidationFailure>());
    });

    test('лишние байты после серий — ValidationFailure', () {
      final Uint8List bytes = GridCodec.encode(Grid.empty(width: 2, height: 2));
      final Uint8List padded = Uint8List.fromList(<int>[...bytes, 0]);

      expect(GridCodec.decode(padded).failureOrNull, isA<ValidationFailure>());
    });

    test('серия нулевой длины — ValidationFailure', () {
      // версия 1, 1×1, значение 0, счётчик 0
      final Uint8List bytes = Uint8List.fromList(<int>[1, 1, 0, 1, 0, 0, 0, 0]);

      expect(GridCodec.decode(bytes).failureOrNull, isA<ValidationFailure>());
    });

    test('переполненный varint — ValidationFailure', () {
      final Uint8List bytes = Uint8List.fromList(<int>[
        1,
        1,
        0,
        1,
        0,
        0,
        0,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0x01,
      ]);

      expect(GridCodec.decode(bytes).failureOrNull, isA<ValidationFailure>());
    });
  });
}
