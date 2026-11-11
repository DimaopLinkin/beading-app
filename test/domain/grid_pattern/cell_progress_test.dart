import 'dart:typed_data';

import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/domain/grid_pattern/stitch_counters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CellProgress', () {
    test('пустой: ничего не сделано, блоков нет', () {
      final CellProgress p = CellProgress(width: 40);
      expect(p.isEmpty, isTrue);
      expect(p.count, 0);
      expect(p.isDone(3, 3), isFalse);
      expect(const CellProgress.none().isEmpty, isTrue);
    });

    test('отметка и снятие; клетки в разных блоках; индекс блока по ширине', () {
      final CellProgress p = CellProgress(
        width: 40,
      ).withCells(const <CellPosition>[CellPosition(0, 0), CellPosition(17, 0), CellPosition(39, 33)], done: true);
      expect(p.isDone(0, 0), isTrue);
      expect(p.isDone(17, 0), isTrue);
      expect(p.isDone(39, 33), isTrue);
      expect(p.isDone(1, 0), isFalse);
      expect(p.count, 3);
      // Шаг строки блоков фиксирован: клетка (39, 33) — блок (2, 2) с индексом 2 * 4096 + 2.
      expect(p.blocks.keys.toList()..sort(), <int>[0, 1, 8194]);
      final CellProgress cleared = p.withCells(const <CellPosition>[CellPosition(17, 0)], done: false);
      expect(cleared.isDone(17, 0), isFalse);
      expect(cleared.blocks.keys.toList()..sort(), <int>[0, 8194], reason: 'опустевший блок не хранится');
    });

    test('клетки вне ширины и с отрицательными номерами игнорируются', () {
      final CellProgress p = CellProgress(
        width: 5,
      ).withCells(const <CellPosition>[CellPosition(5, 0), CellPosition(-1, 0), CellPosition(0, -1)], done: true);
      expect(p.isEmpty, isTrue);
      expect(p.isDone(5, 0), isFalse);
    });

    test('cells возвращает отмеченные клетки по рядам; height отрезает лишнее', () {
      final CellProgress p = CellProgress(
        width: 20,
      ).withCells(const <CellPosition>[CellPosition(19, 1), CellPosition(2, 0), CellPosition(3, 20)], done: true);
      expect(p.cells().toList(), const <CellPosition>[CellPosition(2, 0), CellPosition(19, 1), CellPosition(3, 20)]);
      expect(p.cells(height: 10).toList(), const <CellPosition>[CellPosition(2, 0), CellPosition(19, 1)]);
    });

    test('resized: клетки вне схемы отбрасываются, индексы блоков те же', () {
      final CellProgress p = CellProgress(
        width: 40,
      ).withCells(const <CellPosition>[CellPosition(35, 1), CellPosition(2, 2), CellPosition(10, 30)], done: true);
      final CellProgress r = p.resized(newWidth: 20, newHeight: 20);
      expect(r.width, 20);
      expect(r.cells().toList(), const <CellPosition>[CellPosition(2, 2)]);
      final CellProgress wider = p.resized(newWidth: 100, newHeight: 100);
      expect(wider.count, 3);
      expect(wider.isDone(35, 1), isTrue);
      expect(wider.isDone(10, 30), isTrue);
    });

    test('changedBlocksFrom: изменившиеся блоки, снятый блок — пустые байты', () {
      final CellProgress a = CellProgress(width: 40).withCells(const <CellPosition>[CellPosition(0, 0)], done: true);
      final CellProgress b = a.withCells(const <CellPosition>[CellPosition(17, 0)], done: true);
      expect(b.changedBlocksFrom(a).keys, <int>[1]);
      final CellProgress c = b.withCells(const <CellPosition>[CellPosition(0, 0)], done: false);
      expect(c.changedBlocksFrom(b)[0], isEmpty);
      expect(b.changedBlocksFrom(b), isEmpty);
    });

    test('равенство по содержимому', () {
      final CellProgress a = CellProgress(width: 8).withCells(const <CellPosition>[CellPosition(1, 1)], done: true);
      final CellProgress b = CellProgress(width: 8).withCells(const <CellPosition>[CellPosition(1, 1)], done: true);
      expect(a, b);
      expect(a == a.withCells(const <CellPosition>[CellPosition(2, 2)], done: true), isFalse);
    });

    test('блок неверной длины игнорируется, а не ломает чтение', () {
      final CellProgress p = CellProgress(width: 8, blocks: <int, Uint8List>{0: Uint8List(3)..[0] = 1});
      expect(p.isEmpty, isTrue);
      expect(p.isDone(0, 0), isFalse);
    });

    test('повторная отметка ничего не меняет', () {
      final CellProgress a = CellProgress(width: 8).withCells(const <CellPosition>[CellPosition(1, 1)], done: true);
      expect(a.withCells(const <CellPosition>[CellPosition(1, 1)], done: true), a);
    });
  });

  group('StitchCounters', () {
    final Grid grid = Grid.fromCells(width: 3, height: 2, cells: const <int>[1, 2, 0, 1, 1, 2]);

    test('по цветам: всего, сделано, осталось; пустые клетки не считаются', () {
      final CellProgress p = CellProgress(width: 3).withCells(const <CellPosition>[
        CellPosition(0, 0),
        CellPosition(2, 0),
        CellPosition(2, 1),
      ], done: true);
      final List<ColorCount> counts = StitchCounters.byColor(grid, p, paletteSize: 3);
      expect(counts[0], const ColorCount(color: 0, total: 3, done: 1));
      expect(counts[0].remaining, 2);
      expect(counts[1], const ColorCount(color: 1, total: 2, done: 1));
      expect(counts[2], const ColorCount(color: 2, total: 0, done: 0));
      // Отметка на пустой клетке (2, 0) в счёт не идёт.
      expect(StitchCounters.overall(grid, p), (total: 5, done: 2));
    });
  });
}
