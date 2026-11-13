import 'package:beading/domain/editor/shape_edit.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/domain/grid_pattern/use_cases/shift_progress.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_grid_pattern.dart';

void main() {
  late FakeGridProgressStore rows;
  late FakeCellProgressStore cells;
  late ShiftProgress shift;

  setUp(() {
    rows = FakeGridProgressStore();
    cells = FakeCellProgressStore(width: 8);
    shift = ShiftProgress(rows: rows, cells: cells);
  });

  const ShapeEdit insertRow2 = ShapeEdit(axis: ShapeAxis.row, at: 2, insert: true);
  const ShapeEdit deleteRow2 = ShapeEdit(axis: ShapeAxis.row, at: 2, insert: false);

  test('вставка ряда на станке сдвигает отметки ниже, вставленный ряд без отметки', () async {
    rows
      ..rows.addAll(<int>{0, 1, 2, 5})
      ..currentRow = 3
      ..currentBead = 4;
    await shift('p', const RectangularGeometry(), insertRow2);
    expect(rows.rows, <int>{0, 1, 3, 6});
    expect(rows.rows.contains(2), isFalse);
    expect(rows.currentRow, 4);
    expect(rows.currentBead, 4);
  });

  test('удаление ряда: его отметка пропадает, нижние поднимаются, текущий ряд на месте', () async {
    rows
      ..rows.addAll(<int>{0, 2, 3, 5})
      ..currentRow = 2
      ..currentBead = 1;
    await shift('p', const BrickGeometry(), deleteRow2);
    expect(rows.rows, <int>{0, 2, 4});
    expect(rows.currentRow, 2);
    expect(rows.currentBead, isNull);
  });

  test('отмена вставки возвращает отметки на места', () async {
    rows.rows.addAll(<int>{0, 1, 3, 6});
    await shift('p', const RectangularGeometry(), insertRow2.inverse);
    expect(rows.rows, <int>{0, 1, 2, 5});
  });

  test('пейот: столбец сдвигает ряды плетения на единицу меньше, у края не трогает', () async {
    rows.rows.addAll(<int>{0, 1, 4});
    await shift('p', const PeyoteGeometry(), const ShapeEdit(axis: ShapeAxis.column, at: 3, insert: true));
    expect(rows.rows, <int>{0, 1, 5});
    await shift('p', const PeyoteGeometry(), const ShapeEdit(axis: ShapeAxis.column, at: 1, insert: true));
    expect(rows.rows, <int>{0, 1, 5});
  });

  test('ряд станка не реагирует на вставку столбца', () async {
    rows.rows.addAll(<int>{0, 1});
    await shift('p', const RectangularGeometry(), const ShapeEdit(axis: ShapeAxis.column, at: 0, insert: true));
    expect(rows.rows, <int>{0, 1});
    expect(rows.calls, isEmpty);
  });

  test('вышивка: клетки идут за рядом и столбцом, в вставленном ряду отметок нет', () async {
    await cells.setCells('p', const <CellPosition>[
      CellPosition(1, 1),
      CellPosition(3, 2),
      CellPosition(7, 4),
    ], done: true);
    await shift('p', const RectangularGeometry(), insertRow2);
    CellProgress now = (await cells.load('p')).valueOrNull!;
    expect(now.cells().toList(), const <CellPosition>[CellPosition(1, 1), CellPosition(3, 3), CellPosition(7, 5)]);

    await shift('p', const RectangularGeometry(), const ShapeEdit(axis: ShapeAxis.column, at: 3, insert: false));
    now = (await cells.load('p')).valueOrNull!;
    expect(now.cells().toList(), const <CellPosition>[CellPosition(1, 1), CellPosition(6, 5)]);
  });

  test('вставка столбца у правого края не теряет отметки', () async {
    await cells.setCells('p', const <CellPosition>[CellPosition(7, 0)], done: true);
    await shift('p', const RectangularGeometry(), const ShapeEdit(axis: ShapeAxis.column, at: 0, insert: true));
    final CellProgress now = (await cells.load('p')).valueOrNull!;
    // Фейк держит ширину 8, поэтому смотрим на число отметок: клетка не потерялась.
    expect(now.count, 1);
  });

  test('без отметок ничего не пишет', () async {
    await shift('p', const RectangularGeometry(), insertRow2);
    expect(rows.calls, isEmpty);
    expect(cells.calls, isEmpty);
  });
}
