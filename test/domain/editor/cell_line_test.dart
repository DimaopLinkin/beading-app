import 'package:beading/domain/editor/cell_line.dart';
import 'package:beading/domain/editor/technique_geometry.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cellLine', () {
    test('одна ячейка — она же', () {
      expect(cellLine(const CellPosition(2, 3), const CellPosition(2, 3)), const <CellPosition>[CellPosition(2, 3)]);
    });

    test('горизонталь без пропусков в обе стороны', () {
      expect(
        cellLine(const CellPosition(0, 1), const CellPosition(3, 1)),
        const <CellPosition>[CellPosition(0, 1), CellPosition(1, 1), CellPosition(2, 1), CellPosition(3, 1)],
      );
      expect(cellLine(const CellPosition(3, 1), const CellPosition(0, 1)).map((c) => c.column), <int>[3, 2, 1, 0]);
    });

    test('диагональ и крутой отрезок: соседние ячейки не дальше одной по каждой оси', () {
      for (final (CellPosition, CellPosition) pair in <(CellPosition, CellPosition)>[
        (const CellPosition(0, 0), const CellPosition(5, 5)),
        (const CellPosition(0, 0), const CellPosition(2, 9)),
        (const CellPosition(7, 1), const CellPosition(0, 4)),
      ]) {
        final List<CellPosition> line = cellLine(pair.$1, pair.$2);
        expect(line.first, pair.$1);
        expect(line.last, pair.$2);
        for (int i = 1; i < line.length; i++) {
          expect((line[i].column - line[i - 1].column).abs(), lessThanOrEqualTo(1));
          expect((line[i].row - line[i - 1].row).abs(), lessThanOrEqualTo(1));
        }
      }
    });
  });

  group('geometryForTechnique', () {
    test('станок и квадратный стежок — ровная сетка', () {
      expect(geometryForTechnique(Technique.loom), const GridGeometry.rectangular());
      expect(geometryForTechnique(Technique.square), const GridGeometry.rectangular());
    });

    test('мозаика — пейот, кирпичик — brick', () {
      expect(geometryForTechnique(Technique.peyote), const GridGeometry.peyote());
      expect(geometryForTechnique(Technique.brick), const GridGeometry.brick());
    });
  });
}
