import 'dart:typed_data';

import 'package:beading/domain/grid/cell_position.dart';

/// Отметки «сделано» по клеткам вышивки: битовые блоки 16×16 (по 32 байта).
///
/// Блок с индексом `by * blockStride + bx` хранит клетки `[bx*16, bx*16+16) × [by*16, by*16+16)`; бит клетки внутри
/// блока — `(row % 16) * 16 + column % 16`. Целиком пустые блоки не хранятся. Значение неизменяемо.
///
/// Блоки — единица записи и слияния при синхронизации (LWW по блоку, см. docs/data-and-sync.md). Индекс блока не
/// зависит от размера схемы (шаг строки блоков фиксирован), поэтому смена размера индексы не меняет: [resized] лишь
/// отбрасывает клетки вне схемы.
final class CellProgress {
  CellProgress({required this.width, Map<int, Uint8List> blocks = const <int, Uint8List>{}})
    : assert(width >= 0, 'ширина не может быть отрицательной'),
      _blocks = Map<int, Uint8List>.unmodifiable(<int, Uint8List>{
        for (final MapEntry<int, Uint8List> e in blocks.entries)
          if (e.value.length == blockBytes && _hasBits(e.value)) e.key: Uint8List.fromList(e.value),
      });

  CellProgress._shared(this.width, this._blocks);

  /// Нет ни одной отметки; ширина не важна.
  const CellProgress.none() : width = 0, _blocks = const <int, Uint8List>{};

  /// Сторона блока в клетках.
  static const int blockSide = 16;

  /// Шаг строки блоков в индексе: схема шире `blockStride * 16` клеток не бывает.
  static const int blockStride = 4096;

  /// Байт в блоке.
  static const int blockBytes = blockSide * blockSide ~/ 8;

  final int width;
  final Map<int, Uint8List> _blocks;

  /// Непустые блоки по индексу (копия; менять нельзя).
  Map<int, Uint8List> get blocks => _blocks;

  bool get isEmpty => _blocks.isEmpty;

  /// Сколько клеток отмечено.
  int get count {
    int total = 0;
    for (final Uint8List block in _blocks.values) {
      for (final int byte in block) {
        total += _bitCount[byte];
      }
    }
    return total;
  }

  bool isDone(int column, int row) {
    if (column < 0 || row < 0 || column >= width) {
      return false;
    }
    final Uint8List? block = _blocks[_blockIndex(column, row)];
    if (block == null) {
      return false;
    }
    final int bit = _bitIndex(column, row);
    return block[bit >> 3] & (1 << (bit & 7)) != 0;
  }

  /// Отмеченные клетки в порядке «ряд за рядом»; [height] ограничивает ряды (лишние отбрасываются).
  Iterable<CellPosition> cells({int? height}) {
    final List<CellPosition> result = <CellPosition>[];
    for (final MapEntry<int, Uint8List> e in _blocks.entries) {
      final int bx = e.key % blockStride;
      final int by = e.key ~/ blockStride;
      for (int bit = 0; bit < blockSide * blockSide; bit++) {
        if (e.value[bit >> 3] & (1 << (bit & 7)) != 0) {
          final int column = bx * blockSide + bit % blockSide;
          final int row = by * blockSide + bit ~/ blockSide;
          if (column < width && (height == null || row < height)) {
            result.add(CellPosition(column, row));
          }
        }
      }
    }
    result.sort((a, b) => a.row != b.row ? a.row - b.row : a.column - b.column);
    return result;
  }

  /// Копия, где [cells] отмечены ([done] = `true`) или сняты. Клетки вне ширины пропускаются; высоту проверяет вызывающий.
  CellProgress withCells(Iterable<CellPosition> cells, {required bool done}) {
    // Копируются только затронутые блоки: остальные неизменяемы и разделяются со старым значением. Так отметка одной
    // клетки на большой схеме не стоит копии всего прогресса (мазок вызывает её на каждую клетку).
    final Map<int, Uint8List> next = Map<int, Uint8List>.of(_blocks);
    final Set<int> copied = <int>{};
    for (final CellPosition cell in cells) {
      if (cell.column < 0 || cell.row < 0 || cell.column >= width) {
        continue;
      }
      final int index = _blockIndex(cell.column, cell.row);
      final int bit = _bitIndex(cell.column, cell.row);
      Uint8List? block = next[index];
      if (block == null) {
        if (!done) {
          continue;
        }
        block = next[index] = Uint8List(blockBytes);
        copied.add(index);
      } else if (copied.add(index)) {
        block = next[index] = Uint8List.fromList(block);
      }
      if (done) {
        block[bit >> 3] |= 1 << (bit & 7);
      } else {
        block[bit >> 3] &= ~(1 << (bit & 7));
      }
    }
    for (final int index in copied) {
      if (!_hasBits(next[index]!)) {
        next.remove(index);
      }
    }
    return CellProgress._shared(width, Map<int, Uint8List>.unmodifiable(next));
  }

  /// Прогресс для схемы нового размера: клетки вне неё отбрасываются, индексы блоков пересчитываются.
  CellProgress resized({required int newWidth, required int newHeight}) {
    final CellProgress empty = CellProgress(width: newWidth);
    final Iterable<CellPosition> kept = cells().where((c) => c.column < newWidth && c.row < newHeight);
    return empty.withCells(kept, done: true);
  }

  /// Блоки, которые у [other] отличаются от этого прогресса. Пустой блок — это «блока нет» (`Uint8List(0)`), чтобы
  /// записать снятие отметок.
  Map<int, Uint8List> changedBlocksFrom(CellProgress other) {
    final Map<int, Uint8List> changed = <int, Uint8List>{};
    for (final int index in <int>{...other._blocks.keys, ..._blocks.keys}) {
      final Uint8List? before = other._blocks[index];
      final Uint8List? after = _blocks[index];
      if (!_same(before, after)) {
        changed[index] = after ?? Uint8List(0);
      }
    }
    return changed;
  }

  int _blockIndex(int column, int row) => (row ~/ blockSide) * blockStride + column ~/ blockSide;

  static int _bitIndex(int column, int row) => (row % blockSide) * blockSide + column % blockSide;

  static bool _hasBits(Uint8List block) => block.any((b) => b != 0);

  static bool _same(Uint8List? a, Uint8List? b) {
    if (a == null || b == null) {
      return a == b;
    }
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  static final List<int> _bitCount = List<int>.generate(256, (n) {
    int c = 0;
    for (int v = n; v != 0; v >>= 1) {
      c += v & 1;
    }
    return c;
  });

  /// Равенство по значению без копирования блоков: на большой схеме его зовут на каждый кадр жеста.
  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, поля final, значение неизменяемо
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! CellProgress || other.width != width || other._blocks.length != _blocks.length) {
      return false;
    }
    for (final MapEntry<int, Uint8List> e in _blocks.entries) {
      if (!_same(e.value, other._blocks[e.key])) {
        return false;
      }
    }
    return true;
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, см. выше
  int get hashCode => Object.hash(width, _blocks.length, Object.hashAllUnordered(_blocks.keys));
}
