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
import 'package:beading/domain/stitch/stitch_layers_codec.dart';
import 'package:beading/domain/stitch/stitch_spec.dart';
import 'package:flutter_test/flutter_test.dart';

StitchLayers full() => StitchLayers(
  columns: 40,
  rows: 30,
  defaultSpec: const StitchSpec(crossStrands: 3, backstitchStrands: 2),
  colorSpecs: const <int, StitchSpec>{2: StitchSpec(crossStrands: 1)},
  partials: <PartialStitch>[
    for (final PartialKind k in PartialKind.values)
      PartialStitch(
        column: k.index,
        row: 1,
        kind: k,
        orientation: (k == PartialKind.half || k == PartialKind.tent)
            ? StitchOrientation.backslash
            : StitchOrientation.bottomLeft,
        color: 300,
      ),
  ],
  lines: <LineStitch>[
    LineStitch(a: const LatticeNode(0, 0), b: const LatticeNode(80, 60), kind: LineKind.straight, color: 2),
    LineStitch(a: const LatticeNode(3, 1), b: const LatticeNode(5, 1), kind: LineKind.backstitch, color: 1),
  ],
  points: <PointStitch>[
    PointStitch.knot(node: const LatticeNode(1, 1), kind: PointKind.colonialKnot, color: 4, wraps: 3),
    PointStitch.bead(
      node: const LatticeNode(7, 7),
      bead: const CatalogRef(brand: 'Mill Hill', code: 'Бусина 02012 ё'),
    ),
  ],
);

void main() {
  test('кругом: все виды стежков, сложения и бусины возвращаются как были', () {
    final Result<StitchLayers> back = StitchLayersCodec.decode(StitchLayersCodec.encode(full()));
    expect(back, isA<Success<StitchLayers>>());
    expect((back as Success<StitchLayers>).value, full());
  });

  test('пустые слои — компактный заголовок, и кругом тоже', () {
    final StitchLayers empty = StitchLayers.empty(columns: 5, rows: 6);
    final Uint8List bytes = StitchLayersCodec.encode(empty);
    expect(bytes.length, 11);
    expect(bytes.first, 1);
    expect(((StitchLayersCodec.decode(bytes)) as Success<StitchLayers>).value, empty);
  });

  test('кодирование каноническое: порядок добавления не важен', () {
    final StitchLayers a = StitchLayers(
      columns: 4,
      rows: 4,
      lines: <LineStitch>[
        LineStitch(a: const LatticeNode(0, 0), b: const LatticeNode(1, 0), kind: LineKind.backstitch, color: 1),
        LineStitch(a: const LatticeNode(2, 2), b: const LatticeNode(1, 2), kind: LineKind.backstitch, color: 1),
      ],
    );
    final StitchLayers b = StitchLayers(columns: 4, rows: 4, lines: a.lines.reversed);
    expect(StitchLayersCodec.encode(a), StitchLayersCodec.encode(b));
  });

  test('бусина с самым длинным артикулом проходит круг, длиннее — не создаётся', () {
    final String code = 'ё' * 128;
    final StitchLayers l = StitchLayers(
      columns: 2,
      rows: 2,
      points: <PointStitch>[
        PointStitch.bead(
          node: const LatticeNode(1, 1),
          bead: CatalogRef(brand: 'b', code: code),
        ),
      ],
    );
    expect((StitchLayersCodec.decode(StitchLayersCodec.encode(l)) as Success<StitchLayers>).value, l);
    expect(
      () => PointStitch.bead(
        node: const LatticeNode(1, 1),
        bead: CatalogRef(brand: 'b', code: '${code}x'),
      ),
      throwsArgumentError,
    );
    expect(
      () => PointStitch.bead(
        node: const LatticeNode(1, 1),
        bead: CatalogRef(brand: 'b' * 257, code: 'c'),
      ),
      throwsArgumentError,
    );
  });

  test('записи не в каноническом порядке отвергаются', () {
    List<int> hdr() => <int>[1, 3, 0, 3, 0, 2, 1, 0];
    // два неполных крестика: (1,0) раньше (0,0)
    List<int> p(int col) => <int>[col, 0, 0, 0, 0, 4, 1, 0];
    expect(
      StitchLayersCodec.decode(Uint8List.fromList(<int>[...hdr(), 2, ...p(0), ...p(1), 0, 0])),
      isA<Success<StitchLayers>>(),
    );
    expect(
      StitchLayersCodec.decode(Uint8List.fromList(<int>[...hdr(), 2, ...p(1), ...p(0), 0, 0])),
      isA<Err<StitchLayers>>(),
    );
  });

  test('через GridLayersBlob; чужая версия кодека — ошибка', () {
    final GridLayersBlob blob = StitchLayersCodec.toBlob(full());
    expect(blob.codecVersion, StitchLayersCodec.version);
    expect((StitchLayersCodec.fromBlob(blob) as Success<StitchLayers>).value, full());
    expect(StitchLayersCodec.fromBlob(GridLayersBlob(codecVersion: 9, bytes: blob.bytes)), isA<Err<StitchLayers>>());
  });

  group('повреждённые данные — Err, а не исключение', () {
    final Uint8List good = StitchLayersCodec.encode(full());

    void expectErr(List<int> bytes) {
      final Result<StitchLayers> r = StitchLayersCodec.decode(Uint8List.fromList(bytes));
      expect(r, isA<Err<StitchLayers>>(), reason: '$bytes');
      expect((r as Err<StitchLayers>).failure, isA<ValidationFailure>());
    }

    test('пусто, чужая версия, обрезка на любом месте, лишние байты', () {
      expectErr(const <int>[]);
      expectErr(<int>[2, ...good.skip(1)]);
      for (int n = 0; n < good.length; n++) {
        expectErr(good.sublist(0, n));
      }
      expectErr(<int>[...good, 0]);
    });

    List<int> hdr({int cols = 2, int rows = 2, int cross = 2, int back = 1}) => <int>[1, cols, 0, rows, 0, cross, back];

    test('размер, сложения, вид, повторы, выход за схему', () {
      expectErr(<int>[...hdr(cols: 0), 0, 0, 0, 0]);
      expectErr(<int>[...hdr(cross: 0), 0, 0, 0, 0]);
      expectErr(<int>[...hdr(back: 7), 0, 0, 0, 0]);
      expectErr(<int>[...hdr(), 1, 5, 0, 0, 1, 0, 0, 0, 0]); // в сложениях по цвету 0 сложений крестика
      expectErr(<int>[...hdr(), 2, 5, 0, 2, 1, 5, 0, 2, 1, 0, 0, 0]); // повтор цвета
      expectErr(<int>[...hdr(), 0, 1, 0, 0, 0, 0, 9, 0, 1, 0, 0, 0]); // неизвестный вид
      expectErr(<int>[...hdr(), 0, 1, 0, 0, 0, 0, 0, 9, 1, 0, 0, 0]); // неизвестная ориентация
      expectErr(<int>[...hdr(), 0, 1, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0]); // цвет 0
      expectErr(<int>[...hdr(), 0, 1, 5, 0, 0, 0, 0, 4, 1, 0, 0, 0]); // клетка вне схемы
      expectErr(<int>[...hdr(), 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0]); // линия нулевой длины
    });

    test('счётчики: слишком большой, неканонический, слишком длинный', () {
      expectErr(<int>[...hdr(), 0xff, 0xff, 0xff, 0xff, 0xff, 0x01]);
      expectErr(<int>[...hdr(), 0x80, 0x00]);
      expectErr(<int>[...hdr(), 100]);
    });

    test('бусина: ненулевые цвет и обороты, слишком длинная строка, битый utf-8', () {
      List<int> point(List<int> body) => <int>[...hdr(), 0, 0, 0, 1, ...body];
      expectErr(point(<int>[1, 0, 1, 0, 2, 1, 0, 0, 0, 0])); // цвет 1
      expectErr(point(<int>[1, 0, 1, 0, 2, 0, 0, 1, 0, 0])); // обороты 1
      expectErr(point(<int>[1, 0, 1, 0, 2, 0, 0, 0, 0xff, 0x7f])); // строка 16383 байта
      expectErr(point(<int>[1, 0, 1, 0, 2, 0, 0, 0, 1, 0xff, 0])); // не utf-8
      expectErr(point(<int>[1, 0, 1, 0, 2, 0, 0, 0, 0xac, 0x02, ...List<int>.filled(300, 65)]));
      expect(
        StitchLayersCodec.decode(Uint8List.fromList(point(<int>[1, 0, 1, 0, 2, 0, 0, 0, 0, 0]))),
        isA<Success<StitchLayers>>(),
      );
    });
  });
}
