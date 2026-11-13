import 'dart:collection';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/editor/cell_rect.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';

/// К какому краю прижата сетка при изменении размера.
enum ResizeAnchor { topLeft, top, topRight, left, center, right, bottomLeft, bottom, bottomRight }

/// Команды редактора: чистые функции над [Grid]. Исходная сетка не меняется, результат — новая сетка.
///
/// Необязательный `within` ограничивает команду выделением; без него команда действует на всю сетку. Команды
/// работают с индексами ячеек. От геометрии зависит только заливка (соседство); зеркало и вставки сохраняют
/// ячейки и их порядок, а не физическую раскладку (у пейота с чётным числом столбцов зеркало по горизонтали
/// даёт смещение на ½ ячейки — это свойство самой раскладки).
abstract final class EditorCommands {
  /// Кисть: ставит [value] в ячейки [cells]. Ячейки вне сетки (и вне [within]) пропускаются.
  /// Мазок — это один вызов с набором ячеек.
  static Grid paint(Grid grid, Iterable<CellPosition> cells, int value, {CellRect? within}) {
    _checkValue(value);
    Uint16List? buffer;
    for (final CellPosition cell in cells) {
      if (!_inGrid(grid, cell) || (within != null && !within.contains(cell))) continue;
      final int index = cell.row * grid.width + cell.column;
      if ((buffer ?? grid.cells)[index] == value) continue;
      buffer ??= Uint16List.fromList(grid.cells);
      buffer[index] = value;
    }
    return buffer == null ? grid : Grid.fromCells(width: grid.width, height: grid.height, cells: buffer);
  }

  /// Ластик: очищает ячейки.
  static Grid erase(Grid grid, Iterable<CellPosition> cells, {CellRect? within}) =>
      paint(grid, cells, 0, within: within);

  /// Пипетка: индекс палитры в ячейке или `null`, если ячейка вне сетки.
  static int? pick(Grid grid, CellPosition cell) => _inGrid(grid, cell) ? grid.at(cell.column, cell.row) : null;

  /// Заливка: заменяет на [value] связную область одного цвета от [start]; связность задаёт [geometry].
  /// С [within] область не выходит за выделение. Старт вне сетки или выделения — без изменений.
  static Grid floodFill(Grid grid, GridGeometry geometry, CellPosition start, int value, {CellRect? within}) {
    _checkValue(value);
    if (!_inGrid(grid, start) || (within != null && !within.contains(start))) return grid;
    final int target = grid.at(start.column, start.row);
    if (target == value) return grid;
    final Uint16List buffer = Uint16List.fromList(grid.cells);
    final Queue<CellPosition> queue = Queue<CellPosition>()..add(start);
    buffer[start.row * grid.width + start.column] = value;
    while (queue.isNotEmpty) {
      final CellPosition cell = queue.removeFirst();
      for (final CellPosition next in geometry.neighbors(columns: grid.width, rows: grid.height, cell: cell)) {
        if (within != null && !within.contains(next)) continue;
        final int index = next.row * grid.width + next.column;
        if (buffer[index] != target) continue;
        buffer[index] = value;
        queue.add(next);
      }
    }
    return Grid.fromCells(width: grid.width, height: grid.height, cells: buffer);
  }

  /// Заменить цвет [from] на [to] во всей сетке или в выделении.
  static Grid replaceColor(Grid grid, int from, int to, {CellRect? within}) {
    _checkValue(to);
    if (from == to) return grid;
    return _mapRect(grid, within, (v) => v == from ? to : v);
  }

  /// Поменять два цвета местами во всей сетке или в выделении.
  static Grid swapColors(Grid grid, int a, int b, {CellRect? within}) {
    _checkValue(a);
    _checkValue(b);
    if (a == b) return grid;
    return _mapRect(grid, within, (v) => v == a ? b : (v == b ? a : v));
  }

  /// Зеркало по горизонтали (лево ↔ право) для всей сетки или выделения.
  static Grid mirrorHorizontal(Grid grid, {CellRect? within}) =>
      _transformRect(grid, within, (r, c, row) => (r.left + r.right - c, row));

  /// Зеркало по вертикали (верх ↔ низ) для всей сетки или выделения.
  static Grid mirrorVertical(Grid grid, {CellRect? within}) =>
      _transformRect(grid, within, (r, c, row) => (c, r.top + r.bottom - row));

  /// Вставляет пустой (или залитый [fill]) ряд перед рядом [at]; `at == height` — в конец.
  static Result<Grid> insertRow(Grid grid, int at, {int fill = 0}) {
    _checkValue(fill);
    if (at < 0 || at > grid.height) return Err<Grid>(ValidationFailure('позиция ряда $at вне 0..${grid.height}'));
    if (grid.height >= Grid.maxSide) return const Err<Grid>(ValidationFailure('достигнут максимум рядов'));
    final Uint16List out = Uint16List((grid.height + 1) * grid.width);
    final int w = grid.width;
    out.setRange(0, at * w, grid.cells);
    if (fill != 0) out.fillRange(at * w, (at + 1) * w, fill);
    out.setRange((at + 1) * w, out.length, grid.cells, at * w);
    return _checked(w, grid.height + 1, out);
  }

  /// Удаляет ряд [at]. Последний ряд удалить нельзя.
  static Result<Grid> deleteRow(Grid grid, int at) {
    if (at < 0 || at >= grid.height) return Err<Grid>(ValidationFailure('ряд $at вне 0..${grid.height - 1}'));
    if (grid.height == 1) return const Err<Grid>(ValidationFailure('нельзя удалить последний ряд'));
    final int w = grid.width;
    final Uint16List out = Uint16List((grid.height - 1) * w);
    out.setRange(0, at * w, grid.cells);
    out.setRange(at * w, out.length, grid.cells, (at + 1) * w);
    return _checked(w, grid.height - 1, out);
  }

  /// Вставляет столбец перед столбцом [at]; `at == width` — в конец.
  static Result<Grid> insertColumn(Grid grid, int at, {int fill = 0}) {
    _checkValue(fill);
    if (at < 0 || at > grid.width) return Err<Grid>(ValidationFailure('позиция столбца $at вне 0..${grid.width}'));
    if (grid.width >= Grid.maxSide) return const Err<Grid>(ValidationFailure('достигнут максимум столбцов'));
    final int w = grid.width + 1;
    final Uint16List out = Uint16List(w * grid.height);
    for (int row = 0; row < grid.height; row++) {
      for (int col = 0; col < w; col++) {
        out[row * w + col] = col < at ? grid.at(col, row) : (col == at ? fill : grid.at(col - 1, row));
      }
    }
    return _checked(w, grid.height, out);
  }

  /// Удаляет столбец [at]. Последний столбец удалить нельзя.
  static Result<Grid> deleteColumn(Grid grid, int at) {
    if (at < 0 || at >= grid.width) return Err<Grid>(ValidationFailure('столбец $at вне 0..${grid.width - 1}'));
    if (grid.width == 1) return const Err<Grid>(ValidationFailure('нельзя удалить последний столбец'));
    final int w = grid.width - 1;
    final Uint16List out = Uint16List(w * grid.height);
    for (int row = 0; row < grid.height; row++) {
      for (int col = 0; col < w; col++) {
        out[row * w + col] = grid.at(col < at ? col : col + 1, row);
      }
    }
    return _checked(w, grid.height, out);
  }

  /// Меняет размер: лишнее обрезается, новое пусто. [anchor] — к какому краю прижато содержимое.
  static Result<Grid> resize(
    Grid grid, {
    required int width,
    required int height,
    ResizeAnchor anchor = ResizeAnchor.topLeft,
  }) {
    if (width < 1 || width > Grid.maxSide || height < 1 || height > Grid.maxSide) {
      return Err<Grid>(ValidationFailure('размер $width×$height вне 1..${Grid.maxSide}'));
    }
    final int dx = anchorOffset(anchor, horizontal: true, from: grid.width, to: width);
    final int dy = anchorOffset(anchor, horizontal: false, from: grid.height, to: height);
    final Uint16List out = Uint16List(width * height);
    for (int row = 0; row < height; row++) {
      final int srcRow = row - dy;
      if (srcRow < 0 || srcRow >= grid.height) continue;
      for (int col = 0; col < width; col++) {
        final int srcCol = col - dx;
        if (srcCol < 0 || srcCol >= grid.width) continue;
        out[row * width + col] = grid.at(srcCol, srcRow);
      }
    }
    return _checked(width, height, out);
  }

  /// Сдвиг содержимого (в ячейках) при смене размера с `from` на `to` по одной оси.
  static int anchorOffset(ResizeAnchor anchor, {required bool horizontal, required int from, required int to}) {
    final int delta = to - from;
    final int side = switch (anchor) {
      ResizeAnchor.topLeft => horizontal ? 0 : 0,
      ResizeAnchor.top => horizontal ? 1 : 0,
      ResizeAnchor.topRight => horizontal ? 2 : 0,
      ResizeAnchor.left => horizontal ? 0 : 1,
      ResizeAnchor.center => 1,
      ResizeAnchor.right => horizontal ? 2 : 1,
      ResizeAnchor.bottomLeft => horizontal ? 0 : 2,
      ResizeAnchor.bottom => horizontal ? 1 : 2,
      ResizeAnchor.bottomRight => 2,
    };
    return switch (side) {
      0 => 0,
      1 => delta ~/ 2,
      _ => delta,
    };
  }

  static bool _inGrid(Grid grid, CellPosition cell) =>
      cell.column >= 0 && cell.column < grid.width && cell.row >= 0 && cell.row < grid.height;

  static void _checkValue(int value) {
    if (value < 0 || value > Grid.maxValue) throw ArgumentError.value(value, 'value', 'от 0 до ${Grid.maxValue}');
  }

  static Result<Grid> _checked(int width, int height, Uint16List cells) =>
      Success<Grid>(Grid.fromCells(width: width, height: height, cells: cells));

  static Grid _mapRect(Grid grid, CellRect? within, int Function(int value) map) {
    final CellRect? rect = (within ?? CellRect.all(grid)).clipTo(grid);
    if (rect == null) return grid;
    final Uint16List out = Uint16List.fromList(grid.cells);
    bool changed = false;
    for (int row = rect.top; row <= rect.bottom; row++) {
      for (int col = rect.left; col <= rect.right; col++) {
        final int index = row * grid.width + col;
        final int next = map(out[index]);
        if (next != out[index]) {
          out[index] = next;
          changed = true;
        }
      }
    }
    return changed ? Grid.fromCells(width: grid.width, height: grid.height, cells: out) : grid;
  }

  static Grid _transformRect(Grid grid, CellRect? within, (int, int) Function(CellRect rect, int col, int row) source) {
    final CellRect? rect = (within ?? CellRect.all(grid)).clipTo(grid);
    if (rect == null) return grid;
    final Uint16List out = Uint16List.fromList(grid.cells);
    for (int row = rect.top; row <= rect.bottom; row++) {
      for (int col = rect.left; col <= rect.right; col++) {
        final (int sc, int sr) = source(rect, col, row);
        out[row * grid.width + col] = grid.at(sc, sr);
      }
    }
    return Grid.fromCells(width: grid.width, height: grid.height, cells: out);
  }
}
