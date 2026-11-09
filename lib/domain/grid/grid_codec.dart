import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/grid.dart';

/// Двоичный формат сетки, версия 1.
///
/// ```text
/// version:u8  width:u16le  height:u16le  { value:u16le  count:varint }*
/// ```
///
/// Серии идут по рядам, слева направо; `count` — число подряд идущих ячеек с одним значением (LEB128, не меньше 1).
/// Сумма счётчиков равна `width × height`.
abstract final class GridCodec {
  /// Текущая версия формата.
  static const int version = 1;

  static const int _headerLength = 5;
  static const int _maxVarintBytes = 5;

  static Uint8List encode(Grid grid) {
    final BytesBuilder builder = BytesBuilder(copy: false)
      ..addByte(version)
      ..add(_u16(grid.width))
      ..add(_u16(grid.height));
    final Uint16List cells = grid.cells;
    int start = 0;
    while (start < cells.length) {
      final int value = cells[start];
      int end = start + 1;
      while (end < cells.length && cells[end] == value) {
        end++;
      }
      builder
        ..add(_u16(value))
        ..add(_varint(end - start));
      start = end;
    }
    return builder.takeBytes();
  }

  static Result<Grid> decode(Uint8List bytes) {
    if (bytes.isEmpty) return const Err<Grid>(ValidationFailure('Пустые данные сетки'));
    if (bytes[0] != version) {
      return Err<Grid>(ValidationFailure('Неизвестная версия сетки: ${bytes[0]}'));
    }
    if (bytes.length < _headerLength) return const Err<Grid>(ValidationFailure('Заголовок сетки обрезан'));
    final ByteData data = ByteData.sublistView(bytes);
    final int width = data.getUint16(1, Endian.little);
    final int height = data.getUint16(3, Endian.little);
    if (width < 1 || width > Grid.maxSide || height < 1 || height > Grid.maxSide) {
      return Err<Grid>(ValidationFailure('Недопустимый размер сетки: $width×$height'));
    }

    final int total = width * height;
    final Uint16List cells = Uint16List(total);
    int offset = _headerLength;
    int filled = 0;
    while (offset < bytes.length) {
      if (offset + 2 > bytes.length) return const Err<Grid>(ValidationFailure('Серия сетки обрезана'));
      final int value = data.getUint16(offset, Endian.little);
      offset += 2;

      int count = 0;
      int shift = 0;
      bool finished = false;
      for (int i = 0; i < _maxVarintBytes && offset < bytes.length; i++) {
        final int byte = bytes[offset++];
        count |= (byte & 0x7f) << shift;
        shift += 7;
        if (byte & 0x80 == 0) {
          finished = true;
          break;
        }
      }
      if (!finished) return const Err<Grid>(ValidationFailure('Счётчик серии обрезан или слишком длинный'));
      if (count < 1) return const Err<Grid>(ValidationFailure('Серия нулевой длины'));
      if (filled + count > total) return const Err<Grid>(ValidationFailure('Серии длиннее сетки'));

      cells.fillRange(filled, filled + count, value);
      filled += count;
    }
    if (filled != total) return const Err<Grid>(ValidationFailure('Серии короче сетки'));
    return Success<Grid>(Grid.fromCells(width: width, height: height, cells: cells));
  }

  static Uint8List _u16(int value) => Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little);

  static Uint8List _varint(int value) {
    final List<int> out = <int>[];
    int rest = value;
    while (rest >= 0x80) {
      out.add((rest & 0x7f) | 0x80);
      rest >>= 7;
    }
    out.add(rest);
    return Uint8List.fromList(out);
  }
}
