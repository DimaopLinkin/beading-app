import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:beading/domain/stitch/point_stitch.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_spec.dart';
import 'package:flutter_test/flutter_test.dart';

PartialStitch partial(int c, int r, PartialKind k, StitchOrientation o, [int color = 1]) =>
    PartialStitch(column: c, row: r, kind: k, orientation: o, color: color);

void main() {
  group('StitchSpec', () {
    test('по умолчанию 2 сложения крестика и 1 бэкстича', () {
      expect(const StitchSpec().crossStrands, 2);
      expect(const StitchSpec().backstitchStrands, 1);
    });

    test('по плотности канвы: Аида 11 — 3, 14 и 18 — 2, плотнее — 1; бэкстич всегда 1', () {
      expect(StitchSpec.forDensity(11).crossStrands, 3);
      expect(StitchSpec.forDensity(14).crossStrands, 2);
      expect(StitchSpec.forDensity(18).crossStrands, 2);
      expect(StitchSpec.forDensity(28).crossStrands, 1);
      expect(StitchSpec.forDensity(11).backstitchStrands, 1);
    });

    test('copyWith', () {
      expect(const StitchSpec().copyWith(crossStrands: 3), const StitchSpec(crossStrands: 3));
      expect(const StitchSpec().copyWith(backstitchStrands: 2), const StitchSpec(backstitchStrands: 2));
    });
  });

  group('LatticeNode', () {
    test('углы и центры клеток', () {
      expect(const LatticeNode.corner(2, 3), const LatticeNode(4, 6));
      expect(const LatticeNode.center(2, 3), const LatticeNode(5, 7));
      expect(const LatticeNode(4, 6).isCorner, isTrue);
      expect(const LatticeNode(5, 7).isCenter, isTrue);
      expect(const LatticeNode(5, 6).isCorner || const LatticeNode(5, 6).isCenter, isFalse);
    });

    test('порядок: по рядам, затем по столбцам', () {
      expect(const LatticeNode(5, 0).compareTo(const LatticeNode(0, 1)), lessThan(0));
      expect(const LatticeNode(1, 1).compareTo(const LatticeNode(2, 1)), lessThan(0));
      expect(const LatticeNode(1, 1).shifted(2, 4), const LatticeNode(3, 5));
      expect(const LatticeNode(1, 1).toString(), 'Node(1, 1)');
    });
  });

  group('PartialStitch', () {
    test('диагональ — только полукрестику и гобеленовому, угол — остальным', () {
      expect(() => partial(0, 0, PartialKind.half, StitchOrientation.topLeft), throwsArgumentError);
      expect(() => partial(0, 0, PartialKind.tent, StitchOrientation.bottomRight), throwsArgumentError);
      expect(() => partial(0, 0, PartialKind.quarter, StitchOrientation.slash), throwsArgumentError);
      expect(() => partial(0, 0, PartialKind.threeQuarter, StitchOrientation.backslash), throwsArgumentError);
      expect(() => partial(0, 0, PartialKind.petit, StitchOrientation.slash), throwsArgumentError);
      partial(0, 0, PartialKind.half, StitchOrientation.slash);
      partial(0, 0, PartialKind.tent, StitchOrientation.backslash);
      partial(0, 0, PartialKind.threeQuarter, StitchOrientation.topRight);
    });

    test('цвет от 1, клетка не отрицательная', () {
      expect(() => partial(0, 0, PartialKind.half, StitchOrientation.slash, 0), throwsArgumentError);
      expect(() => partial(0, 0, PartialKind.half, StitchOrientation.slash, 65536), throwsArgumentError);
      expect(() => partial(-1, 0, PartialKind.half, StitchOrientation.slash), throwsArgumentError);
      expect(() => partial(0, -1, PartialKind.half, StitchOrientation.slash), throwsArgumentError);
    });

    test('ключ не зависит от цвета; порядок — ряд, столбец, вид, ориентация', () {
      final PartialStitch a = partial(1, 0, PartialKind.half, StitchOrientation.slash);
      final PartialStitch b = partial(1, 0, PartialKind.half, StitchOrientation.slash, 5);
      expect(a.key, b.key);
      expect(a.copyWith(color: 5), b);
      expect(a.cell.column, 1);
      expect(
        partial(
          5,
          0,
          PartialKind.half,
          StitchOrientation.slash,
        ).compareTo(partial(0, 1, PartialKind.half, StitchOrientation.slash)),
        lessThan(0),
      );
      expect(
        partial(
          0,
          0,
          PartialKind.half,
          StitchOrientation.slash,
        ).compareTo(partial(1, 0, PartialKind.half, StitchOrientation.slash)),
        lessThan(0),
      );
      expect(
        partial(
          0,
          0,
          PartialKind.half,
          StitchOrientation.slash,
        ).compareTo(partial(0, 0, PartialKind.tent, StitchOrientation.slash)),
        lessThan(0),
      );
      expect(
        partial(
          0,
          0,
          PartialKind.quarter,
          StitchOrientation.topLeft,
        ).compareTo(partial(0, 0, PartialKind.quarter, StitchOrientation.topRight)),
        lessThan(0),
      );
    });
  });

  group('LineStitch', () {
    test('концы упорядочиваются, направление не важно', () {
      final LineStitch a = LineStitch(
        a: const LatticeNode(4, 4),
        b: const LatticeNode(0, 0),
        kind: LineKind.backstitch,
        color: 2,
      );
      final LineStitch b = LineStitch(
        a: const LatticeNode(0, 0),
        b: const LatticeNode(4, 4),
        kind: LineKind.backstitch,
        color: 2,
      );
      expect(a, b);
      expect(a.from, const LatticeNode(0, 0));
      expect(a.key, b.key);
    });

    test('нулевая длина и цвет 0 отклоняются', () {
      expect(
        () => LineStitch(a: const LatticeNode(1, 1), b: const LatticeNode(1, 1), kind: LineKind.straight, color: 1),
        throwsArgumentError,
      );
      expect(
        () => LineStitch(a: const LatticeNode(1, 1), b: const LatticeNode(2, 1), kind: LineKind.straight, color: 0),
        throwsArgumentError,
      );
    });

    test('порядок по началу, затем по концу', () {
      final LineStitch l1 = LineStitch(
        a: const LatticeNode(0, 0),
        b: const LatticeNode(1, 0),
        kind: LineKind.backstitch,
        color: 1,
      );
      final LineStitch l2 = LineStitch(
        a: const LatticeNode(0, 0),
        b: const LatticeNode(2, 0),
        kind: LineKind.backstitch,
        color: 1,
      );
      final LineStitch l3 = LineStitch(
        a: const LatticeNode(2, 0),
        b: const LatticeNode(3, 0),
        kind: LineKind.backstitch,
        color: 1,
      );
      expect(l1.compareTo(l2), lessThan(0));
      expect(l2.compareTo(l3), lessThan(0));
    });
  });

  group('PointStitch', () {
    test('узелок: обороты 1–4 и цвет от 1', () {
      expect(PointStitch.knot(node: const LatticeNode(1, 1), kind: PointKind.frenchKnot, color: 1).wraps, 2);
      expect(
        () => PointStitch.knot(node: const LatticeNode(1, 1), kind: PointKind.frenchKnot, color: 1, wraps: 0),
        throwsArgumentError,
      );
      expect(
        () => PointStitch.knot(node: const LatticeNode(1, 1), kind: PointKind.colonialKnot, color: 1, wraps: 5),
        throwsArgumentError,
      );
      expect(
        () => PointStitch.knot(node: const LatticeNode(1, 1), kind: PointKind.colonialKnot, color: 0),
        throwsArgumentError,
      );
      expect(
        () => PointStitch.knot(node: const LatticeNode(1, 1), kind: PointKind.bead, color: 1),
        throwsArgumentError,
      );
    });

    test('бусина хранит позицию каталога, без цвета', () {
      const CatalogRef ref = CatalogRef(brand: 'Mill Hill', code: '02012');
      final PointStitch p = PointStitch.bead(node: const LatticeNode(3, 3), bead: ref);
      expect(p.bead, ref);
      expect(p.color, 0);
      expect(p.compareTo(PointStitch.bead(node: const LatticeNode(1, 5), bead: ref)), lessThan(0));
    });
  });

  group('StitchLayers', () {
    test('пустые слои', () {
      final StitchLayers l = StitchLayers.empty(columns: 3, rows: 2);
      expect(l.isEmpty, isTrue);
      expect(l.usedColors, isEmpty);
      expect(l.specFor(7), const StitchSpec());
    });

    test('сложения: у цвета своё, иначе по умолчанию', () {
      final StitchLayers l = StitchLayers(
        columns: 3,
        rows: 2,
        defaultSpec: const StitchSpec(crossStrands: 3),
        colorSpecs: const <int, StitchSpec>{4: StitchSpec()},
      );
      expect(l.specFor(4).crossStrands, 2);
      expect(l.specFor(1).crossStrands, 3);
      expect(
        () => StitchLayers(columns: 3, rows: 2, colorSpecs: const <int, StitchSpec>{0: StitchSpec()}),
        throwsArgumentError,
      );
    });

    test('записи сортируются; usedColors собирает цвета со всех слоёв, кроме бусин', () {
      final StitchLayers l = StitchLayers(
        columns: 3,
        rows: 2,
        partials: <PartialStitch>[
          partial(2, 1, PartialKind.half, StitchOrientation.slash, 3),
          partial(0, 0, PartialKind.half, StitchOrientation.slash),
        ],
        lines: <LineStitch>[
          LineStitch(a: const LatticeNode(0, 0), b: const LatticeNode(6, 0), kind: LineKind.backstitch, color: 5),
        ],
        points: <PointStitch>[
          PointStitch.knot(node: const LatticeNode(1, 1), kind: PointKind.frenchKnot, color: 7),
          PointStitch.bead(
            node: const LatticeNode(3, 3),
            bead: const CatalogRef(brand: 'b', code: 'c'),
          ),
        ],
      );
      expect(l.partials.first.column, 0);
      expect(l.usedColors, <int>{1, 3, 5, 7});
      expect(l.isEmpty, isFalse);
    });

    test('вне схемы, повторы и размер — ошибки', () {
      expect(() => StitchLayers.empty(columns: 0, rows: 1), throwsArgumentError);
      expect(() => StitchLayers.empty(columns: 1, rows: 5000), throwsArgumentError);
      expect(
        () => StitchLayers(
          columns: 2,
          rows: 2,
          partials: <PartialStitch>[partial(2, 0, PartialKind.half, StitchOrientation.slash)],
        ),
        throwsArgumentError,
      );
      expect(
        () => StitchLayers(
          columns: 2,
          rows: 2,
          partials: <PartialStitch>[partial(0, 2, PartialKind.half, StitchOrientation.slash)],
        ),
        throwsArgumentError,
      );
      expect(
        () => StitchLayers(
          columns: 2,
          rows: 2,
          partials: <PartialStitch>[
            partial(0, 0, PartialKind.half, StitchOrientation.slash),
            partial(0, 0, PartialKind.half, StitchOrientation.slash, 2),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => StitchLayers(
          columns: 2,
          rows: 2,
          lines: <LineStitch>[
            LineStitch(a: const LatticeNode(0, 0), b: const LatticeNode(5, 0), kind: LineKind.straight, color: 1),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => StitchLayers(
          columns: 2,
          rows: 2,
          lines: <LineStitch>[
            LineStitch(a: const LatticeNode(0, 0), b: const LatticeNode(0, 5), kind: LineKind.straight, color: 1),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => StitchLayers(
          columns: 2,
          rows: 2,
          lines: <LineStitch>[
            LineStitch(a: const LatticeNode(5, 0), b: const LatticeNode(5, 1), kind: LineKind.straight, color: 1),
          ],
        ),
        throwsArgumentError,
      );
      final LineStitch l = LineStitch(
        a: const LatticeNode(0, 0),
        b: const LatticeNode(1, 0),
        kind: LineKind.straight,
        color: 1,
      );
      expect(() => StitchLayers(columns: 2, rows: 2, lines: <LineStitch>[l, l]), throwsArgumentError);
      expect(
        () => StitchLayers(
          columns: 2,
          rows: 2,
          points: <PointStitch>[PointStitch.knot(node: const LatticeNode(5, 0), kind: PointKind.frenchKnot, color: 1)],
        ),
        throwsArgumentError,
      );
      expect(
        () => StitchLayers(
          columns: 2,
          rows: 2,
          points: <PointStitch>[PointStitch.knot(node: const LatticeNode(0, 5), kind: PointKind.frenchKnot, color: 1)],
        ),
        throwsArgumentError,
      );
      final PointStitch k = PointStitch.knot(node: const LatticeNode(1, 1), kind: PointKind.frenchKnot, color: 1);
      expect(() => StitchLayers(columns: 2, rows: 2, points: <PointStitch>[k, k]), throwsArgumentError);
    });

    test('слои неизменяемы', () {
      final StitchLayers l = StitchLayers.empty(columns: 2, rows: 2);
      expect(() => l.partials.add(partial(0, 0, PartialKind.half, StitchOrientation.slash)), throwsUnsupportedError);
    });
  });
}
