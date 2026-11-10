import 'dart:ui';

import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain/grid/fake_cell_metrics.dart';

void main() {
  const FakeCellMetrics wide = FakeCellMetrics(2, 1);

  test('меньшая сторона ячейки равна заданным пикселям', () {
    final GridScene scene = GridScene(
      geometry: const GridGeometry.rectangular(),
      metrics: wide,
      columns: 10,
      rows: 5,
      smallestCellPx: 20,
    );
    expect(scene.cellSize, const Size(40, 20));
    expect(scene.size, const Size(400, 100));
  });

  test('cellRect и cellAt согласованы для всех геометрий', () {
    for (final GridGeometry g in <GridGeometry>[
      const GridGeometry.rectangular(),
      const GridGeometry.peyote(),
      const GridGeometry.brick(),
    ]) {
      final GridScene scene = GridScene(geometry: g, metrics: wide, columns: 7, rows: 6);
      for (int row = 0; row < 6; row++) {
        for (int column = 0; column < 7; column++) {
          final CellPosition cell = CellPosition(column, row);
          expect(scene.cellAt(scene.cellRect(cell).center), cell, reason: '$g $cell');
        }
      }
    }
  });

  test('точка за схемой не попадает ни в одну ячейку', () {
    final GridScene scene = GridScene(geometry: const GridGeometry.rectangular(), metrics: wide, columns: 3, rows: 3);
    expect(scene.cellAt(const Offset(-1, 5)), isNull);
    expect(scene.cellAt(Offset(scene.size.width + 1, 5)), isNull);
  });

  test('rowBounds покрывает все ячейки ряда', () {
    for (final GridGeometry g in <GridGeometry>[const GridGeometry.peyote(), const GridGeometry.brick()]) {
      final GridScene scene = GridScene(geometry: g, metrics: wide, columns: 9, rows: 6);
      for (int row = 0; row < 6; row++) {
        final Rect bounds = scene.rowBounds(row);
        for (int column = 0; column < 9; column++) {
          final Rect cell = scene.cellRect(CellPosition(column, row));
          expect(bounds.contains(cell.center), isTrue, reason: '$g $column,$row');
        }
      }
    }
  });

  test('rowBounds верен для пейота с большим drop', () {
    final GridScene scene = GridScene(geometry: const GridGeometry.peyote(drop: 4), metrics: wide, columns: 6, rows: 3);
    final Rect bounds = scene.rowBounds(1);
    for (int column = 0; column < 6; column++) {
      final Rect cell = scene.cellRect(CellPosition(column, 1));
      expect(bounds.top <= cell.top && bounds.bottom >= cell.bottom, isTrue, reason: 'столбец $column');
    }
  });

  test('rowPath ступенчатого ряда не заходит на соседний ряд', () {
    final GridScene scene = GridScene(geometry: const GridGeometry.peyote(), metrics: wide, columns: 4, rows: 4);
    final Rect cell = scene.cellRect(const CellPosition(0, 2));
    final Path path = scene.rowPath(2);
    expect(path.contains(cell.center), isTrue);
    expect(path.contains(scene.cellRect(const CellPosition(0, 3)).center), isFalse);
  });
}
