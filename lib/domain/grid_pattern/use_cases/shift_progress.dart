import 'dart:typed_data';

import 'package:beading/domain/editor/shape_edit.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/domain/grid_pattern/cell_progress_store.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/grid_pattern/grid_progress_store.dart';

/// Сдвигает отметки прогресса вслед за вставкой или удалением ряда или столбца: отметки остаются на своих клетках,
/// вставленный ряд без отметок, отметки удалённого ряда пропадают.
///
/// Работает через обычные записи обоих хранилищ (отметить, снять, записать блоки), поэтому синхронизация видит их как
/// обычные правки. Вызывается до сохранения схемы нового размера: сохранение обрезает отметки вне схемы.
final class ShiftProgress {
  const ShiftProgress({required GridProgressStore rows, required CellProgressStore cells})
    : _rows = rows,
      _cells = cells;

  final GridProgressStore _rows;
  final CellProgressStore _cells;

  Future<void> call(String patternId, GridGeometry geometry, ShapeEdit edit) async {
    await _shiftRows(patternId, geometry, edit);
    await _shiftCells(patternId, edit);
  }

  /// Номер ряда плетения, которому соответствует правка, или `null`, если ряды плетения она не меняет.
  static int? readingAt(GridGeometry geometry, ShapeEdit edit) => switch (geometry) {
    RectangularGeometry() || BrickGeometry() => edit.axis == ShapeAxis.row ? edit.at : null,
    // Первый ряд плетения — два первых столбца: вставка у самого края меняет сборку, её не сдвигаем.
    PeyoteGeometry(:final int drop) when drop == 1 =>
      edit.axis == ShapeAxis.column && edit.at >= 2 ? edit.at - 1 : null,
    PeyoteGeometry() => edit.axis == ShapeAxis.column ? edit.at : null,
  };

  Future<void> _shiftRows(String patternId, GridGeometry geometry, ShapeEdit edit) async {
    final int? at = readingAt(geometry, edit);
    if (at == null) {
      return;
    }
    final GridProgress? progress = (await _rows.load(patternId)).valueOrNull;
    if (progress == null) {
      return;
    }
    final Set<int> before = progress.completedRows;
    final Set<int> after = <int>{
      for (final int r in before)
        if (_shifted(r, at, insert: edit.insert) case final int moved) moved,
    };
    for (final int r in before.difference(after)) {
      await _rows.unmarkRow(patternId, r);
    }
    for (final int r in after.difference(before)) {
      await _rows.markRow(patternId, r);
    }
    final int? current = progress.currentRow;
    if (current != null) {
      final int next = _shifted(current, at, insert: edit.insert) ?? current;
      if (next != current) {
        await _rows.setCurrent(patternId, row: next, bead: progress.currentBead);
      } else if (!edit.insert && current == at) {
        // Текущий ряд удалён: «остановилась здесь» теперь целиком на следующем ряду.
        await _rows.setCurrent(patternId, row: current);
      }
    }
  }

  Future<void> _shiftCells(String patternId, ShapeEdit edit) async {
    final CellProgress? before = (await _cells.load(patternId)).valueOrNull;
    if (before == null || before.isEmpty) {
      return;
    }
    final List<CellPosition> moved = <CellPosition>[];
    for (final CellPosition c in before.cells()) {
      final int? column = edit.axis == ShapeAxis.column ? _shifted(c.column, edit.at, insert: edit.insert) : c.column;
      final int? row = edit.axis == ShapeAxis.row ? _shifted(c.row, edit.at, insert: edit.insert) : c.row;
      if (column != null && row != null) {
        moved.add(CellPosition(column, row));
      }
    }
    // Ширина после вставки столбца больше: клетки у правого края не должны отбрасываться как «вне схемы».
    final int width = before.width + (edit.axis == ShapeAxis.column && edit.insert ? 1 : 0);
    final CellProgress after = CellProgress(width: width).withCells(moved, done: true);
    final Map<int, Uint8List> changes = after.changedBlocksFrom(before);
    if (changes.isNotEmpty) {
      await _cells.writeBlocks(patternId, changes);
    }
  }

  /// Новый номер [n] после вставки перед [at] или удаления [at]; `null` — удалённый.
  static int? _shifted(int n, int at, {required bool insert}) {
    if (insert) {
      return n >= at ? n + 1 : n;
    }
    if (n == at) {
      return null;
    }
    return n > at ? n - 1 : n;
  }
}
