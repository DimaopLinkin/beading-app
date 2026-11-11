import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/pattern_metrics.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import '../grid/fake_cell_metrics.dart';

Grid _grid(int width, List<int> cells) => Grid.fromCells(width: width, height: cells.length ~/ width, cells: cells);

void main() {
  group('countSingleCells', () {
    test('клетка без соседа своего цвета — одиночная', () {
      final Grid grid = _grid(3, <int>[1, 1, 1, 1, 2, 1, 1, 1, 1]);
      expect(countSingleCells(grid, const GridGeometry.rectangular()), 1);
    });

    test('пара клеток одного цвета не одиночные, по диагонали соседство не считается', () {
      final Grid grid = _grid(3, <int>[1, 1, 2, 3, 3, 2, 4, 5, 5]);
      expect(countSingleCells(grid, const GridGeometry.rectangular()), 1);
      final Grid diagonal = _grid(2, <int>[1, 2, 2, 1]);
      expect(countSingleCells(diagonal, const GridGeometry.rectangular()), 4);
    });

    test('пустые клетки не считаются и не соседи', () {
      final Grid grid = _grid(3, <int>[0, 1, 0, 0, 0, 0]);
      expect(countSingleCells(grid, const GridGeometry.rectangular()), 1);
    });

    test('в пейоте соседство со сдвигом: клетки (1, 0) и (0, 1) касаются', () {
      final Grid grid = _grid(2, <int>[1, 2, 2, 1]);
      expect(countSingleCells(grid, const GridGeometry.rectangular()), 4);
      expect(countSingleCells(grid, const GridGeometry.peyote()), 2);
    });
  });

  group('lightnessStructure', () {
    // Фото 2 × 1 клетка по 2 пикселя: слева тёмное, справа светлое.
    final Float32List lightness = Float32List.fromList(<double>[10, 10, 90, 90]);
    final CellRegions regions = CellRegions.forGrid(
      geometry: const GridGeometry.rectangular(),
      metrics: const FakeCellMetrics(1, 1),
      columns: 2,
      rows: 1,
      imageWidth: 4,
      imageHeight: 1,
    );
    const List<PaletteEntry> palette = <PaletteEntry>[
      PaletteEntry(rgb: Rgb(0, 0, 0)),
      PaletteEntry(rgb: Rgb(255, 255, 255)),
    ];

    test('схема повторяет фото: корреляция 1', () {
      final LightnessStructure? s = lightnessStructure(
        lightness: lightness,
        workWidth: 4,
        regions: regions,
        grid: _grid(2, <int>[1, 2]),
        palette: palette,
      );
      expect(s!.correlation, closeTo(1, 1e-6));
      expect(s.contrast, greaterThan(1));
    });

    test('схема наоборот: корреляция −1', () {
      final LightnessStructure? s = lightnessStructure(
        lightness: lightness,
        workWidth: 4,
        regions: regions,
        grid: _grid(2, <int>[2, 1]),
        palette: palette,
      );
      expect(s!.correlation, closeTo(-1, 1e-6));
    });

    test('один цвет на контрастном фото: контраст 0, корреляция 0', () {
      final LightnessStructure? s = lightnessStructure(
        lightness: lightness,
        workWidth: 4,
        regions: regions,
        grid: _grid(2, <int>[1, 1]),
        palette: palette,
      );
      expect(s!.contrast, 0);
      expect(s.correlation, 0);
    });

    test('пустая схема и пустые клетки: пустые не считаются, совсем пустая даёт null', () {
      expect(
        lightnessStructure(
          lightness: lightness,
          workWidth: 4,
          regions: regions,
          grid: _grid(2, <int>[0, 0]),
          palette: palette,
        ),
        isNull,
      );
      final LightnessStructure? one = lightnessStructure(
        lightness: lightness,
        workWidth: 4,
        regions: regions,
        grid: _grid(2, <int>[0, 2]),
        palette: palette,
      );
      // Одна светлая клетка: у фото в ней нет разброса светлоты.
      expect(one, isNull);
    });
  });
}
