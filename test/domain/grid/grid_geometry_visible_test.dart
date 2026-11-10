import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/cell_range.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid/mm.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_cell_metrics.dart';

const FakeCellMetrics _wide = FakeCellMetrics(2, 1);

void main() {
  const Map<String, GridGeometry> geometries = <String, GridGeometry>{
    'rectangular': GridGeometry.rectangular(),
    'peyote': GridGeometry.peyote(),
    '2-drop': GridGeometry.peyote(drop: 2),
    'brick': GridGeometry.brick(),
  };

  group('cellSize', () {
    test('прямоугольная и пейот: размер метрик', () {
      for (final GridGeometry g in <GridGeometry>[const GridGeometry.rectangular(), const GridGeometry.peyote()]) {
        expect(g.cellSize(_wide), const MmSize(2, 1));
      }
    });

    test('кирпичный стежок меняет ширину и высоту местами', () {
      expect(const GridGeometry.brick().cellSize(_wide), const MmSize(1, 2));
    });
  });

  group('visibleCells', () {
    for (final MapEntry<String, GridGeometry> entry in geometries.entries) {
      test('${entry.key}: диапазон содержит каждую ячейку, чей центр в прямоугольнике', () {
        const int columns = 9;
        const int rows = 11;
        final GridGeometry g = entry.value;
        final List<(double, double, double, double)> rects = <(double, double, double, double)>[
          (0, 0, 3, 3),
          (4.2, 2.7, 9.9, 8.1),
          (-5, -5, 100, 100),
          (7.5, 6, 7.6, 6.1),
        ];
        for (final (double l, double t, double r, double b) in rects) {
          final CellRange range = g.visibleCells(
            _wide,
            columns: columns,
            rows: rows,
            left: l,
            top: t,
            right: r,
            bottom: b,
          );
          for (int row = 0; row < rows; row++) {
            for (int column = 0; column < columns; column++) {
              final MmPoint c = g.cellCenter(_wide, CellPosition(column, row));
              if (c.x >= l && c.x <= r && c.y >= t && c.y <= b) {
                expect(range.contains(column, row), isTrue, reason: '$column,$row в ($l,$t,$r,$b)');
              }
            }
          }
        }
      });

      test('${entry.key}: прямоугольник за схемой даёт пустой диапазон', () {
        final CellRange range = entry.value.visibleCells(
          _wide,
          columns: 4,
          rows: 4,
          left: 500,
          top: 500,
          right: 600,
          bottom: 600,
        );
        expect(range.isEmpty, isTrue);
      });
    }

    test('диапазон не выходит за размеры схемы', () {
      final CellRange range = const GridGeometry.rectangular().visibleCells(
        _wide,
        columns: 4,
        rows: 3,
        left: -10,
        top: -10,
        right: 1000,
        bottom: 1000,
      );
      expect(range, const CellRange(firstColumn: 0, lastColumn: 3, firstRow: 0, lastRow: 2));
    });

    test('нечисловые границы дают пустой диапазон', () {
      final CellRange range = const GridGeometry.rectangular().visibleCells(
        _wide,
        columns: 4,
        rows: 3,
        left: double.nan,
        top: 0,
        right: 1,
        bottom: 1,
      );
      expect(range.isEmpty, isTrue);
    });
  });
}
