import 'dart:typed_data';

/// Иммутабельная сетка индексов палитры: `0` — пустая ячейка, остальное — номер цвета.
final class Grid {
  Grid._(this.width, this.height, Uint16List cells) : _cells = cells;

  /// Пустая сетка.
  factory Grid.empty({required int width, required int height}) {
    _checkSize(width, height);
    return Grid._(width, height, Uint16List(width * height));
  }

  /// Сетка из значений по рядам, слева направо. Список копируется.
  factory Grid.fromCells({required int width, required int height, required List<int> cells}) {
    _checkSize(width, height);
    if (cells.length != width * height) {
      throw ArgumentError.value(cells.length, 'cells', 'ожидалось ${width * height} значений');
    }
    for (final int value in cells) {
      _checkValue(value);
    }
    return Grid._(width, height, Uint16List.fromList(cells));
  }

  /// Наибольшая сторона сетки, ячеек.
  static const int maxSide = 4096;

  /// Наибольший индекс палитры.
  static const int maxValue = 0xFFFF;

  final int width;
  final int height;
  final Uint16List _cells;

  /// Значения по рядам, слева направо. Только для чтения.
  Uint16List get cells => _cells.asUnmodifiableView();

  /// Индекс палитры в ячейке.
  int at(int column, int row) => _cells[_indexOf(column, row)];

  /// Копия сетки с новым значением в ячейке.
  Grid withCell(int column, int row, int value) {
    final int index = _indexOf(column, row);
    _checkValue(value);
    return Grid._(width, height, Uint16List.fromList(_cells)..[index] = value);
  }

  int _indexOf(int column, int row) {
    RangeError.checkValueInInterval(column, 0, width - 1, 'column');
    RangeError.checkValueInInterval(row, 0, height - 1, 'row');
    return row * width + column;
  }

  static void _checkSize(int width, int height) {
    if (width < 1 || width > maxSide) throw ArgumentError.value(width, 'width', 'от 1 до $maxSide');
    if (height < 1 || height > maxSide) throw ArgumentError.value(height, 'height', 'от 1 до $maxSide');
  }

  static void _checkValue(int value) {
    if (value < 0 || value > maxValue) throw ArgumentError.value(value, 'value', 'от 0 до $maxValue');
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, поля final, буфер наружу не отдаётся (только view)
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Grid || other.width != width || other.height != height) return false;
    for (int i = 0; i < _cells.length; i++) {
      if (_cells[i] != other._cells[i]) return false;
    }
    return true;
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, см. выше
  int get hashCode => Object.hash(width, height, Object.hashAll(_cells));
}
