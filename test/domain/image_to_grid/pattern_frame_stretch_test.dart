import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/pattern_frame.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GeneratedPattern small() => GeneratedPattern(
    grid: Grid.fromCells(width: 2, height: 2, cells: Uint16List.fromList(<int>[1, 2, 3, 0])),
    palette: const <PaletteEntry>[
      PaletteEntry(rgb: Rgb(255, 0, 0)),
      PaletteEntry(rgb: Rgb(0, 255, 0)),
      PaletteEntry(rgb: Rgb(0, 0, 255)),
    ],
  );

  group('PatternFrame.stretch', () {
    test('каждая клетка превращается в блок; палитра та же', () {
      final GeneratedPattern big = PatternFrame.stretch(small(), 6, 4);
      expect(big.grid.width, 6);
      expect(big.grid.height, 4);
      expect(big.grid.cells, <int>[
        1, 1, 1, 2, 2, 2, //
        1, 1, 1, 2, 2, 2,
        3, 3, 3, 0, 0, 0,
        3, 3, 3, 0, 0, 0,
      ]);
      expect(big.palette, hasLength(3));
    });

    test('нецелое отношение: края на месте, размер точный', () {
      final GeneratedPattern big = PatternFrame.stretch(small(), 5, 3);
      expect((big.grid.width, big.grid.height), (5, 3));
      expect(big.grid.at(0, 0), 1);
      expect(big.grid.at(4, 0), 2);
      expect(big.grid.at(0, 2), 3);
      expect(big.grid.at(4, 2), 0);
    });

    test('тот же размер — тот же объект', () {
      final GeneratedPattern p = small();
      expect(identical(PatternFrame.stretch(p, 2, 2), p), isTrue);
    });
  });
}
