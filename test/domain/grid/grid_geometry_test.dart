import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid/mm.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_cell_metrics.dart';

const FakeCellMetrics _unit = FakeCellMetrics(1, 1);
const FakeCellMetrics _wide = FakeCellMetrics(2, 1);

Matcher _near(double x, double y) =>
    isA<MmPoint>().having((p) => p.x, 'x', closeTo(x, 1e-9)).having((p) => p.y, 'y', closeTo(y, 1e-9));

Matcher _nearSize(double width, double height) => isA<MmSize>()
    .having((s) => s.width, 'width', closeTo(width, 1e-9))
    .having((s) => s.height, 'height', closeTo(height, 1e-9));

CellPosition _p(int column, int row) => CellPosition(column, row);

void main() {
  group('rectangular', () {
    const GridGeometry geometry = GridGeometry.rectangular();

    test('центры ячеек с размером 2×1', () {
      expect(geometry.cellCenter(_wide, _p(0, 0)), _near(1, 0.5));
      expect(geometry.cellCenter(_wide, _p(3, 2)), _near(7, 2.5));
    });

    test('квадратная ячейка 1×1', () {
      expect(geometry.cellCenter(_unit, _p(0, 0)), _near(0.5, 0.5));
      expect(geometry.cellCenter(_unit, _p(2, 4)), _near(2.5, 4.5));
    });

    test('габариты', () {
      expect(geometry.extent(_wide, columns: 4, rows: 3), _nearSize(8, 3));
      expect(geometry.extent(_unit, columns: 1, rows: 1), _nearSize(1, 1));
    });

    test('Delica 11/0 на станке: ширина — длина вдоль отверстия, высота — диаметр', () {
      final MmPoint center = geometry.cellCenter(BeadSize.delica11, _p(0, 0));

      expect(center.x, closeTo(BeadSize.delica11.holeLengthMm / 2, 1e-9));
      expect(center.y, closeTo(BeadSize.delica11.diameterMm / 2, 1e-9));
      final MmSize size = geometry.extent(BeadSize.delica11, columns: 10, rows: 20);
      expect(size.width, closeTo(10 * BeadSize.delica11.holeLengthMm, 1e-9));
      expect(size.height, closeTo(20 * BeadSize.delica11.diameterMm, 1e-9));
    });

    test('hit-test: внутри ячейки, на границах и вне сетки', () {
      MmPoint at(double x, double y) => MmPoint(x, y);

      expect(geometry.cellAt(_wide, columns: 4, rows: 3, point: at(1, 0.5)), _p(0, 0));
      expect(geometry.cellAt(_wide, columns: 4, rows: 3, point: at(2, 0)), _p(1, 0));
      expect(geometry.cellAt(_wide, columns: 4, rows: 3, point: at(7.99, 2.99)), _p(3, 2));
      expect(geometry.cellAt(_wide, columns: 4, rows: 3, point: at(8, 1)), isNull);
      expect(geometry.cellAt(_wide, columns: 4, rows: 3, point: at(4, 3)), isNull);
      expect(geometry.cellAt(_wide, columns: 4, rows: 3, point: at(-0.01, 1)), isNull);
      expect(geometry.cellAt(_wide, columns: 4, rows: 3, point: at(1, -0.01)), isNull);
    });

    test('соседи: четыре по сторонам, по порядку «ряд, потом столбец»', () {
      expect(geometry.neighbors(columns: 3, rows: 3, cell: _p(1, 1)), <CellPosition>[
        _p(1, 0),
        _p(0, 1),
        _p(2, 1),
        _p(1, 2),
      ]);
    });

    test('соседи в углу и в сетке 1×1', () {
      expect(geometry.neighbors(columns: 3, rows: 3, cell: _p(0, 0)), <CellPosition>[_p(1, 0), _p(0, 1)]);
      expect(geometry.neighbors(columns: 3, rows: 3, cell: _p(2, 2)), <CellPosition>[_p(2, 1), _p(1, 2)]);
      expect(geometry.neighbors(columns: 1, rows: 1, cell: _p(0, 0)), isEmpty);
    });
  });

  group('peyote(drop: 1)', () {
    const GridGeometry geometry = GridGeometry.peyote();

    test('нечётные столбцы сдвинуты вниз на половину ячейки', () {
      expect(geometry.cellCenter(_wide, _p(0, 0)), _near(1, 0.5));
      expect(geometry.cellCenter(_wide, _p(1, 0)), _near(3, 1));
      expect(geometry.cellCenter(_wide, _p(2, 0)), _near(5, 0.5));
      expect(geometry.cellCenter(_wide, _p(1, 2)), _near(3, 3));
    });

    test('габариты: добавляется половина ячейки, если есть сдвинутый столбец', () {
      expect(geometry.extent(_wide, columns: 3, rows: 2), _nearSize(6, 2.5));
      expect(geometry.extent(_wide, columns: 1, rows: 2), _nearSize(2, 2));
    });

    test('hit-test: пустота над сдвинутым столбцом и под несдвинутым', () {
      expect(geometry.cellAt(_wide, columns: 3, rows: 2, point: const MmPoint(3, 0.25)), isNull);
      expect(geometry.cellAt(_wide, columns: 3, rows: 2, point: const MmPoint(3, 0.5)), _p(1, 0));
      expect(geometry.cellAt(_wide, columns: 3, rows: 2, point: const MmPoint(1, 2.25)), isNull);
      expect(geometry.cellAt(_wide, columns: 3, rows: 2, point: const MmPoint(3, 2.25)), _p(1, 1));
      expect(geometry.cellAt(_wide, columns: 3, rows: 2, point: const MmPoint(3, 2.5)), isNull);
    });

    test('соседи сдвинутой ячейки: по две в соседних столбцах', () {
      expect(geometry.neighbors(columns: 3, rows: 3, cell: _p(1, 1)), <CellPosition>[
        _p(1, 0),
        _p(0, 1),
        _p(2, 1),
        _p(0, 2),
        _p(1, 2),
        _p(2, 2),
      ]);
    });

    test('соседи несдвинутой ячейки у сдвинутого столбца', () {
      expect(geometry.neighbors(columns: 3, rows: 3, cell: _p(0, 1)), <CellPosition>[
        _p(0, 0),
        _p(1, 0),
        _p(1, 1),
        _p(0, 2),
      ]);
    });

    test('соседи не выходят за сетку', () {
      expect(geometry.neighbors(columns: 2, rows: 1, cell: _p(1, 0)), <CellPosition>[_p(0, 0)]);
      expect(geometry.neighbors(columns: 2, rows: 1, cell: _p(0, 0)), <CellPosition>[_p(1, 0)]);
    });

    test('соседство симметрично', () {
      _expectSymmetricNeighbors(geometry, columns: 5, rows: 4);
    });
  });

  group('peyote(drop: 2)', () {
    const GridGeometry geometry = GridGeometry.peyote(drop: 2);

    test('столбцы сдвигаются парами', () {
      expect(geometry.cellCenter(_wide, _p(0, 0)), _near(1, 0.5));
      expect(geometry.cellCenter(_wide, _p(1, 0)), _near(3, 0.5));
      expect(geometry.cellCenter(_wide, _p(2, 0)), _near(5, 1));
      expect(geometry.cellCenter(_wide, _p(3, 0)), _near(7, 1));
      expect(geometry.cellCenter(_wide, _p(4, 0)), _near(9, 0.5));
    });

    test('габариты: без сдвига, пока столбцов не больше drop', () {
      expect(geometry.extent(_wide, columns: 2, rows: 3), _nearSize(4, 3));
      expect(geometry.extent(_wide, columns: 3, rows: 3), _nearSize(6, 3.5));
    });

    test('соседи внутри пары как в прямоугольной сетке, между парами — по два', () {
      expect(geometry.neighbors(columns: 4, rows: 3, cell: _p(1, 1)), <CellPosition>[
        _p(1, 0),
        _p(2, 0),
        _p(0, 1),
        _p(2, 1),
        _p(1, 2),
      ]);
    });

    test('соседство симметрично', () {
      _expectSymmetricNeighbors(geometry, columns: 7, rows: 4);
    });

    test('drop меньше 1 запрещён', () {
      expect(() => GridGeometry.peyote(drop: 0), throwsAssertionError);
    });
  });

  group('brick', () {
    const GridGeometry geometry = GridGeometry.brick();

    test('нечётные ряды сдвинуты вправо на половину ячейки, размеры меняются местами', () {
      // метрики 2×1: в кирпичном стежке отверстие поперёк, поэтому ячейка 1×2
      expect(geometry.cellCenter(_wide, _p(0, 0)), _near(0.5, 1));
      expect(geometry.cellCenter(_wide, _p(1, 0)), _near(1.5, 1));
      expect(geometry.cellCenter(_wide, _p(0, 1)), _near(1, 3));
      expect(geometry.cellCenter(_wide, _p(1, 1)), _near(2, 3));
    });

    test('габариты: добавляется половина ячейки по ширине', () {
      expect(geometry.extent(_wide, columns: 3, rows: 2), _nearSize(3.5, 4));
      expect(geometry.extent(_wide, columns: 3, rows: 1), _nearSize(3, 2));
    });

    test('рокайль 11/0 в кирпичном стежке: ширина — диаметр, высота — длина вдоль отверстия', () {
      final MmPoint first = geometry.cellCenter(BeadSize.rocaille11, _p(0, 0));
      final MmPoint shifted = geometry.cellCenter(BeadSize.rocaille11, _p(0, 1));

      expect(first.x, closeTo(BeadSize.rocaille11.diameterMm / 2, 1e-9));
      expect(first.y, closeTo(BeadSize.rocaille11.holeLengthMm / 2, 1e-9));
      expect(shifted.x, closeTo(BeadSize.rocaille11.diameterMm, 1e-9));
      expect(shifted.y, closeTo(BeadSize.rocaille11.holeLengthMm * 1.5, 1e-9));
    });

    test('hit-test: пустота слева у сдвинутого ряда', () {
      expect(geometry.cellAt(_wide, columns: 3, rows: 2, point: const MmPoint(0.25, 3)), isNull);
      expect(geometry.cellAt(_wide, columns: 3, rows: 2, point: const MmPoint(0.5, 3)), _p(0, 1));
      expect(geometry.cellAt(_wide, columns: 3, rows: 2, point: const MmPoint(3.25, 1)), isNull);
    });

    test('соседи сдвинутого ряда: по две ячейки сверху и снизу', () {
      expect(geometry.neighbors(columns: 3, rows: 3, cell: _p(1, 1)), <CellPosition>[
        _p(1, 0),
        _p(2, 0),
        _p(0, 1),
        _p(2, 1),
        _p(1, 2),
        _p(2, 2),
      ]);
    });

    test('соседство симметрично', () {
      _expectSymmetricNeighbors(geometry, columns: 4, rows: 5);
    });
  });

  group('для всех геометрий и метрик', () {
    final Map<String, GridGeometry> geometries = <String, GridGeometry>{
      'rectangular': const GridGeometry.rectangular(),
      'peyote(1)': const GridGeometry.peyote(),
      'peyote(2)': const GridGeometry.peyote(drop: 2),
      'peyote(3)': const GridGeometry.peyote(drop: 3),
      'brick': const GridGeometry.brick(),
    };
    final Map<String, FakeCellMetrics> metrics = <String, FakeCellMetrics>{
      'квадрат': _unit,
      'широкая': _wide,
      'узкая': const FakeCellMetrics(1.3, 1.6),
    };

    for (final MapEntry<String, GridGeometry> geometry in geometries.entries) {
      for (final MapEntry<String, FakeCellMetrics> cell in metrics.entries) {
        test('hit-test обратен центрам: ${geometry.key}, ${cell.key}', () {
          const int columns = 7;
          const int rows = 6;
          for (int row = 0; row < rows; row++) {
            for (int column = 0; column < columns; column++) {
              final CellPosition expected = _p(column, row);
              final MmPoint center = geometry.value.cellCenter(cell.value, expected);

              expect(
                geometry.value.cellAt(cell.value, columns: columns, rows: rows, point: center),
                expected,
                reason: 'center of $expected',
              );
            }
          }
        });

        test('центры лежат в габаритах: ${geometry.key}, ${cell.key}', () {
          const int columns = 7;
          const int rows = 6;
          final MmSize size = geometry.value.extent(cell.value, columns: columns, rows: rows);
          for (int row = 0; row < rows; row++) {
            for (int column = 0; column < columns; column++) {
              final MmPoint center = geometry.value.cellCenter(cell.value, _p(column, row));

              expect(center.x, inInclusiveRange(0, size.width));
              expect(center.y, inInclusiveRange(0, size.height));
            }
          }
        });
      }
    }
  });
}

void _expectSymmetricNeighbors(GridGeometry geometry, {required int columns, required int rows}) {
  for (int row = 0; row < rows; row++) {
    for (int column = 0; column < columns; column++) {
      final CellPosition cell = _p(column, row);
      for (final CellPosition neighbor in geometry.neighbors(columns: columns, rows: rows, cell: cell)) {
        expect(
          geometry.neighbors(columns: columns, rows: rows, cell: neighbor),
          contains(cell),
          reason: '$neighbor должен считать соседом $cell',
        );
      }
    }
  }
}
