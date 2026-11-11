import 'dart:convert';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:beading/domain/stitch/point_stitch.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_spec.dart';

/// Двоичный формат слоёв вышивки, версия 1. Числа `u16` — little-endian, `varint` — LEB128 в каноническом виде.
///
/// ```text
/// version:u8  columns:u16  rows:u16  crossStrands:u8  backstitchStrands:u8
/// n:varint  { color:u16  crossStrands:u8  backstitchStrands:u8 }*n                  сложения по цветам
/// n:varint  { column:u16  row:u16  kind:u8  orientation:u8  color:u16 }*n           неполные крестики
/// n:varint  { x1:u16  y1:u16  x2:u16  y2:u16  kind:u8  color:u16 }*n                линии
/// n:varint  { x:u16  y:u16  kind:u8  color:u16  wraps:u8  [brand:str  code:str] }*n  узелки и бусины (строки — у бусины)
/// str = len:varint  utf8-байты
/// ```
///
/// `kind` и `orientation` — индексы перечислений [PartialKind], [StitchOrientation], [LineKind], [PointKind]; порядок
/// значений в них менять нельзя. Записи идут в каноническом порядке слоя, поэтому одинаковые слои кодируются одинаково.
abstract final class StitchLayersCodec {
  static const int version = 1;

  static const int _maxString = PointStitch.maxRefLength;

  static GridLayersBlob toBlob(StitchLayers layers) => GridLayersBlob(codecVersion: version, bytes: encode(layers));

  static Result<StitchLayers> fromBlob(GridLayersBlob blob) => blob.codecVersion == version
      ? decode(blob.bytes)
      : Err<StitchLayers>(ValidationFailure('Неизвестная версия слоёв вышивки: ${blob.codecVersion}'));

  static Uint8List encode(StitchLayers layers) {
    final BytesBuilder out = BytesBuilder(copy: false)
      ..addByte(version)
      ..add(_u16(layers.columns))
      ..add(_u16(layers.rows))
      ..addByte(layers.defaultSpec.crossStrands)
      ..addByte(layers.defaultSpec.backstitchStrands);
    final List<int> specColors = layers.colorSpecs.keys.toList()..sort();
    out.add(_varint(specColors.length));
    for (final int color in specColors) {
      final StitchSpec spec = layers.colorSpecs[color]!;
      out
        ..add(_u16(color))
        ..addByte(spec.crossStrands)
        ..addByte(spec.backstitchStrands);
    }
    out.add(_varint(layers.partials.length));
    for (final PartialStitch p in layers.partials) {
      out
        ..add(_u16(p.column))
        ..add(_u16(p.row))
        ..addByte(p.kind.index)
        ..addByte(p.orientation.index)
        ..add(_u16(p.color));
    }
    out.add(_varint(layers.lines.length));
    for (final LineStitch l in layers.lines) {
      out
        ..add(_u16(l.from.x))
        ..add(_u16(l.from.y))
        ..add(_u16(l.to.x))
        ..add(_u16(l.to.y))
        ..addByte(l.kind.index)
        ..add(_u16(l.color));
    }
    out.add(_varint(layers.points.length));
    for (final PointStitch p in layers.points) {
      out
        ..add(_u16(p.node.x))
        ..add(_u16(p.node.y))
        ..addByte(p.kind.index)
        ..add(_u16(p.color))
        ..addByte(p.wraps);
      if (p.bead != null) {
        out
          ..add(_string(p.bead!.brand))
          ..add(_string(p.bead!.code));
      }
    }
    return out.takeBytes();
  }

  static Result<StitchLayers> decode(Uint8List bytes) {
    try {
      return Success<StitchLayers>(_decode(bytes));
    } on FormatException catch (e) {
      return Err<StitchLayers>(ValidationFailure('Слои вышивки повреждены: ${e.message}'));
    } on ArgumentError catch (e) {
      return Err<StitchLayers>(ValidationFailure('Слои вышивки недопустимы: ${e.message}'));
    }
  }

  static StitchLayers _decode(Uint8List bytes) {
    final _Reader r = _Reader(bytes);
    final int found = r.u8();
    if (found != version) throw FormatException('неизвестная версия $found');
    final int columns = r.u16();
    final int rows = r.u16();
    final StitchSpec defaultSpec = _spec(r.u8(), r.u8());

    final Map<int, StitchSpec> colorSpecs = <int, StitchSpec>{};
    for (int i = r.count(4); i > 0; i--) {
      final int color = r.u16();
      if (colorSpecs.containsKey(color)) throw const FormatException('повтор цвета в сложениях');
      colorSpecs[color] = _spec(r.u8(), r.u8());
    }
    final List<PartialStitch> partials = <PartialStitch>[];
    for (int i = r.count(8); i > 0; i--) {
      partials.add(
        PartialStitch(
          column: r.u16(),
          row: r.u16(),
          kind: r.enumValue(PartialKind.values),
          orientation: r.enumValue(StitchOrientation.values),
          color: r.u16(),
        ),
      );
    }
    final List<LineStitch> lines = <LineStitch>[];
    for (int i = r.count(11); i > 0; i--) {
      lines.add(
        LineStitch(
          a: LatticeNode(r.u16(), r.u16()),
          b: LatticeNode(r.u16(), r.u16()),
          kind: r.enumValue(LineKind.values),
          color: r.u16(),
        ),
      );
    }
    final List<PointStitch> points = <PointStitch>[];
    for (int i = r.count(8); i > 0; i--) {
      final LatticeNode node = LatticeNode(r.u16(), r.u16());
      final PointKind kind = r.enumValue(PointKind.values);
      final int color = r.u16();
      final int wraps = r.u8();
      if (kind == PointKind.bead) {
        if (color != 0 || wraps != 0) throw const FormatException('у бусины цвет и обороты должны быть нулевыми');
        points.add(
          PointStitch.bead(
            node: node,
            bead: CatalogRef(brand: r.string(_maxString), code: r.string(_maxString)),
          ),
        );
      } else {
        points.add(PointStitch.knot(node: node, kind: kind, color: color, wraps: wraps));
      }
    }
    if (!r.atEnd) throw const FormatException('лишние байты в конце');
    final StitchLayers layers = StitchLayers(
      columns: columns,
      rows: rows,
      defaultSpec: defaultSpec,
      colorSpecs: colorSpecs,
      partials: partials,
      lines: lines,
      points: points,
    );
    // Формат канонический: записи идут строго в порядке слоя, иначе разные байты дали бы одни и те же слои.
    if (!_same(layers.partials, partials) || !_same(layers.lines, lines) || !_same(layers.points, points)) {
      throw const FormatException('записи не в каноническом порядке');
    }
    return layers;
  }

  static bool _same<T>(List<T> a, List<T> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static StitchSpec _spec(int cross, int back) {
    if (cross < StitchSpec.minStrands ||
        cross > StitchSpec.maxStrands ||
        back < StitchSpec.minStrands ||
        back > StitchSpec.maxStrands) {
      throw FormatException('сложения вне 1–${StitchSpec.maxStrands}: $cross, $back');
    }
    return StitchSpec(crossStrands: cross, backstitchStrands: back);
  }

  static Uint8List _u16(int value) => Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little);

  static Uint8List _string(String value) {
    final List<int> utf = utf8.encode(value);
    return Uint8List.fromList(<int>[..._varint(utf.length), ...utf]);
  }

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

class _Reader {
  _Reader(this._bytes) : _data = ByteData.sublistView(_bytes);

  final Uint8List _bytes;
  final ByteData _data;
  int _offset = 0;

  bool get atEnd => _offset == _bytes.length;

  void _need(int n) {
    if (_offset + n > _bytes.length) throw const FormatException('данные обрезаны');
  }

  int u8() {
    _need(1);
    return _bytes[_offset++];
  }

  int u16() {
    _need(2);
    final int v = _data.getUint16(_offset, Endian.little);
    _offset += 2;
    return v;
  }

  T enumValue<T>(List<T> values) {
    final int i = u8();
    if (i >= values.length) throw FormatException('неизвестное значение $i');
    return values[i];
  }

  int varint() {
    int value = 0;
    for (int i = 0; i < 5; i++) {
      final int byte = u8();
      value |= (byte & 0x7f) << (7 * i);
      if (byte & 0x80 == 0) {
        if (i > 0 && byte == 0) throw const FormatException('неканоническая запись счётчика');
        return value;
      }
    }
    throw const FormatException('счётчик слишком длинный');
  }

  /// Число записей; проверяет, что столько записей минимального размера [minSize] ещё может уместиться в данных.
  int count(int minSize) {
    final int n = varint();
    if (n > (_bytes.length - _offset) ~/ minSize) throw const FormatException('записей больше, чем данных');
    return n;
  }

  String string(int maxLength) {
    final int length = varint();
    if (length > maxLength) throw const FormatException('строка слишком длинная');
    _need(length);
    final String s = utf8.decode(_bytes.sublist(_offset, _offset + length));
    _offset += length;
    return s;
  }
}
