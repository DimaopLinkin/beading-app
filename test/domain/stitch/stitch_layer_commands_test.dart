import 'package:beading/domain/editor/editor_commands.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:beading/domain/stitch/point_stitch.dart';
import 'package:beading/domain/stitch/stitch_layer_commands.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_spec.dart';
import 'package:flutter_test/flutter_test.dart';

PartialStitch partial(int c, int r, PartialKind k, StitchOrientation o, [int color = 1]) =>
    PartialStitch(column: c, row: r, kind: k, orientation: o, color: color);

LineStitch line(int x1, int y1, int x2, int y2, [int color = 1, LineKind kind = LineKind.backstitch]) =>
    LineStitch(a: LatticeNode(x1, y1), b: LatticeNode(x2, y2), kind: kind, color: color);

PointStitch knot(int x, int y, [int color = 1]) =>
    PointStitch.knot(node: LatticeNode(x, y), kind: PointKind.frenchKnot, color: color);

StitchLayers empty([int w = 4, int h = 3]) => StitchLayers.empty(columns: w, rows: h);

void main() {
  group('неполные крестики', () {
    test('add заменяет тот же ключ другим цветом, исходные слои не меняются', () {
      final StitchLayers a = StitchLayerCommands.addPartial(
        empty(),
        partial(1, 1, PartialKind.half, StitchOrientation.slash),
      );
      final StitchLayers b = StitchLayerCommands.addPartial(
        a,
        partial(1, 1, PartialKind.half, StitchOrientation.slash, 4),
      );
      expect(a.partials.single.color, 1);
      expect(b.partials.single.color, 4);
    });

    test('в клетке уживаются разные ориентации (четыре четверти)', () {
      StitchLayers l = empty();
      for (final StitchOrientation o in <StitchOrientation>[
        StitchOrientation.topLeft,
        StitchOrientation.topRight,
        StitchOrientation.bottomLeft,
        StitchOrientation.bottomRight,
      ]) {
        l = StitchLayerCommands.addPartial(l, partial(0, 0, PartialKind.quarter, o));
      }
      expect(l.partials, hasLength(4));
    });

    test('вне схемы пропускается', () {
      final StitchLayers l = empty();
      expect(StitchLayerCommands.addPartial(l, partial(4, 0, PartialKind.half, StitchOrientation.slash)), same(l));
      expect(StitchLayerCommands.addPartial(l, partial(0, 3, PartialKind.half, StitchOrientation.slash)), same(l));
    });

    test('remove по ключу и clearCell', () {
      StitchLayers l = StitchLayerCommands.addPartial(
        empty(),
        partial(1, 1, PartialKind.half, StitchOrientation.slash),
      );
      l = StitchLayerCommands.addPartial(l, partial(1, 1, PartialKind.half, StitchOrientation.backslash));
      l = StitchLayerCommands.addPartial(l, partial(2, 1, PartialKind.half, StitchOrientation.slash));
      expect(
        StitchLayerCommands.removePartial(
          l,
          const CellPosition(1, 1),
          PartialKind.half,
          StitchOrientation.slash,
        ).partials,
        hasLength(2),
      );
      expect(
        StitchLayerCommands.removePartial(l, const CellPosition(0, 0), PartialKind.half, StitchOrientation.slash),
        same(l),
      );
      expect(StitchLayerCommands.clearCell(l, const CellPosition(1, 1)).partials.single.column, 2);
      expect(StitchLayerCommands.clearCell(l, const CellPosition(0, 0)), same(l));
    });
  });

  group('линии', () {
    test('одна линия и замена той же между теми же узлами в обратном направлении', () {
      final StitchLayers a = StitchLayerCommands.addLine(empty(), line(0, 0, 2, 2));
      final StitchLayers b = StitchLayerCommands.addLine(a, line(2, 2, 0, 0, 3, LineKind.straight));
      expect(b.lines.single.color, 3);
      expect(StitchLayerCommands.addLine(b, line(2, 2, 0, 0, 3, LineKind.straight)), same(b));
    });

    test('вне схемы пропускается, внутри краёв (2w, 2h) допустима', () {
      final StitchLayers l = empty();
      expect(StitchLayerCommands.addLine(l, line(0, 0, 9, 0)), same(l));
      expect(StitchLayerCommands.addLine(l, line(0, 0, 0, 7)), same(l));
      expect(StitchLayerCommands.addLine(l, line(9, 0, 9, 1)), same(l));
      expect(StitchLayerCommands.addLine(l, line(0, 0, 8, 6)).lines, hasLength(1));
    });

    test('addLines добавляет пачкой: так контуры из картинки ложатся одним шагом', () {
      final StitchLayers l = StitchLayerCommands.addLines(empty(), <LineStitch>[
        line(0, 0, 1, 0),
        line(1, 0, 2, 0),
        line(0, 0, 1, 0, 2),
      ]);
      expect(l.lines, hasLength(2));
      expect(l.lines.first.color, 2);
    });

    test('ломаная соединяет узлы подряд, повторные узлы пропускает', () {
      final StitchLayers l = StitchLayerCommands.addLinePath(
        empty(),
        const <LatticeNode>[LatticeNode(1, 1), LatticeNode(1, 1), LatticeNode(3, 1), LatticeNode(3, 3)],
        kind: LineKind.backstitch,
        color: 2,
      );
      expect(l.lines, hasLength(2));
    });

    test('removeLine не зависит от порядка концов', () {
      final StitchLayers l = StitchLayerCommands.addLine(empty(), line(0, 0, 2, 2));
      expect(StitchLayerCommands.removeLine(l, const LatticeNode(2, 2), const LatticeNode(0, 0)).lines, isEmpty);
      expect(StitchLayerCommands.removeLine(l, const LatticeNode(0, 0), const LatticeNode(2, 2)).lines, isEmpty);
      expect(StitchLayerCommands.removeLine(l, const LatticeNode(0, 0), const LatticeNode(3, 3)), same(l));
    });

    test('линии — отдельный слой: правка крестиков их не трогает', () {
      final StitchLayers l = StitchLayerCommands.addLine(empty(), line(0, 0, 2, 2));
      final StitchLayers p = StitchLayerCommands.addPartial(
        l,
        partial(0, 0, PartialKind.half, StitchOrientation.slash),
      );
      expect(p.lines, l.lines);
    });
  });

  group('точки', () {
    test('add заменяет точку в том же узле; бусина и узелок не уживаются в одном узле', () {
      StitchLayers l = StitchLayerCommands.addPoint(empty(), knot(1, 1));
      l = StitchLayerCommands.addPoint(
        l,
        PointStitch.bead(
          node: const LatticeNode(1, 1),
          bead: const CatalogRef(brand: 'MH', code: '1'),
        ),
      );
      expect(l.points.single.kind, PointKind.bead);
    });

    test('вне схемы пропускается; remove по узлу', () {
      final StitchLayers l = empty();
      expect(StitchLayerCommands.addPoint(l, knot(9, 0)), same(l));
      expect(StitchLayerCommands.addPoint(l, knot(0, 7)), same(l));
      final StitchLayers k = StitchLayerCommands.addPoint(l, knot(1, 1));
      expect(StitchLayerCommands.removePoint(k, const LatticeNode(1, 1)).points, isEmpty);
      expect(StitchLayerCommands.removePoint(k, const LatticeNode(3, 3)), same(k));
    });
  });

  group('сложения', () {
    test('умолчание и переопределение цвета', () {
      final StitchLayers l = empty();
      expect(StitchLayerCommands.setDefaultSpec(l, const StitchSpec()), same(l));
      final StitchLayers a = StitchLayerCommands.setDefaultSpec(l, const StitchSpec(crossStrands: 3));
      expect(a.specFor(1).crossStrands, 3);
      final StitchLayers b = StitchLayerCommands.setColorSpec(a, 2, const StitchSpec(crossStrands: 1));
      expect(b.specFor(2).crossStrands, 1);
      expect(StitchLayerCommands.setColorSpec(b, 2, const StitchSpec(crossStrands: 1)), same(b));
      expect(StitchLayerCommands.setColorSpec(b, 2, null).specFor(2).crossStrands, 3);
      expect(StitchLayerCommands.setColorSpec(a, 2, null), same(a));
    });
  });

  group('палитра', () {
    StitchLayers sample() => StitchLayers(
      columns: 4,
      rows: 3,
      colorSpecs: const <int, StitchSpec>{1: StitchSpec(crossStrands: 3), 2: StitchSpec(crossStrands: 1)},
      partials: <PartialStitch>[
        partial(0, 0, PartialKind.half, StitchOrientation.slash),
        partial(1, 0, PartialKind.half, StitchOrientation.slash, 2),
      ],
      lines: <LineStitch>[line(0, 0, 2, 0), line(0, 2, 2, 2, 2)],
      points: <PointStitch>[
        knot(1, 1),
        knot(3, 1, 2),
        PointStitch.bead(
          node: const LatticeNode(5, 1),
          bead: const CatalogRef(brand: 'MH', code: '1'),
        ),
      ],
    );

    test('тождественная карта ничего не меняет', () {
      final StitchLayers l = sample();
      expect(StitchLayerCommands.reindexColors(l, const PaletteReindex.identity()), same(l));
    });

    test('удаление цвета убирает его записи и сложения, бусины остаются', () {
      final StitchLayers l = StitchLayerCommands.reindexColors(sample(), PaletteReindex(const <int, int>{1: 0}));
      expect(l.partials.map((p) => p.color), <int>[2]);
      expect(l.lines.map((x) => x.color), <int>[2]);
      expect(l.points.map((p) => p.kind), <PointKind>[PointKind.frenchKnot, PointKind.bead]);
      expect(l.colorSpecs.keys, <int>[2]);
    });

    test('сдвиг номеров переносит цвета; слияние цветов оставляет первые сложения', () {
      final StitchLayers shifted = StitchLayerCommands.reindexColors(
        sample(),
        PaletteReindex(const <int, int>{1: 5, 2: 6}),
      );
      expect(shifted.usedColors, <int>{5, 6});
      expect(shifted.specFor(5).crossStrands, 3);
      final StitchLayers merged = StitchLayerCommands.reindexColors(
        StitchLayers(
          columns: 2,
          rows: 2,
          colorSpecs: const <int, StitchSpec>{1: StitchSpec(crossStrands: 3), 2: StitchSpec(crossStrands: 1)},
          partials: <PartialStitch>[partial(0, 0, PartialKind.half, StitchOrientation.slash, 2)],
        ),
        PaletteReindex(const <int, int>{2: 1}),
      );
      expect(merged.partials.single.color, 1);
      expect(merged.colorSpecs[1]!.crossStrands, 3);
    });
  });

  group('зеркало', () {
    StitchLayers sample() => StitchLayers(
      columns: 4,
      rows: 3,
      partials: <PartialStitch>[
        partial(0, 0, PartialKind.quarter, StitchOrientation.topLeft),
        partial(1, 2, PartialKind.half, StitchOrientation.slash),
      ],
      lines: <LineStitch>[line(0, 0, 2, 2)],
      points: <PointStitch>[
        knot(1, 1),
        PointStitch.bead(
          node: const LatticeNode(3, 1),
          bead: const CatalogRef(brand: 'MH', code: '1'),
        ),
      ],
    );

    test('по горизонтали: клетки, углы, диагонали, линии и точки', () {
      final StitchLayers m = StitchLayerCommands.mirrorHorizontal(sample());
      expect(m.partials.map((p) => (p.column, p.orientation)), <(int, StitchOrientation)>[
        (3, StitchOrientation.topRight),
        (2, StitchOrientation.backslash),
      ]);
      expect(m.lines.single.key, (const LatticeNode(8, 0), const LatticeNode(6, 2)));
      expect(m.points.map((p) => p.node.x), <int>[5, 7]);
      expect(StitchLayerCommands.mirrorHorizontal(m), sample());
    });

    test('по вертикали', () {
      final StitchLayers m = StitchLayerCommands.mirrorVertical(sample());
      expect(m.partials.map((p) => (p.row, p.orientation)), <(int, StitchOrientation)>[
        (0, StitchOrientation.backslash),
        (2, StitchOrientation.bottomLeft),
      ]);
      expect(m.lines.single.key, (const LatticeNode(2, 4), const LatticeNode(0, 6)));
      expect(m.points.map((p) => p.node.y), <int>[5, 5]);
      expect(StitchLayerCommands.mirrorVertical(m), sample());
    });

    test('все углы и диагонали зеркалятся и возвращаются обратно', () {
      for (final StitchOrientation o in StitchOrientation.values) {
        final PartialKind kind = (o == StitchOrientation.slash || o == StitchOrientation.backslash)
            ? PartialKind.half
            : PartialKind.quarter;
        final StitchLayers l = StitchLayers(columns: 2, rows: 2, partials: <PartialStitch>[partial(0, 0, kind, o)]);
        expect(StitchLayerCommands.mirrorHorizontal(StitchLayerCommands.mirrorHorizontal(l)), l);
        expect(StitchLayerCommands.mirrorVertical(StitchLayerCommands.mirrorVertical(l)), l);
      }
    });
  });

  group('resize', () {
    StitchLayers sample() => StitchLayers(
      columns: 4,
      rows: 3,
      partials: <PartialStitch>[
        partial(0, 0, PartialKind.half, StitchOrientation.slash),
        partial(3, 2, PartialKind.half, StitchOrientation.slash),
      ],
      lines: <LineStitch>[line(0, 0, 2, 0), line(6, 4, 8, 6)],
      points: <PointStitch>[
        knot(1, 1),
        PointStitch.bead(
          node: const LatticeNode(7, 5),
          bead: const CatalogRef(brand: 'MH', code: '1'),
        ),
      ],
    );

    test('увеличение с якорем сверху слева ничего не двигает', () {
      final StitchLayers l = StitchLayerCommands.resize(sample(), width: 6, height: 5);
      expect(l.columns, 6);
      expect(l.rows, 5);
      expect(l.partials, sample().partials);
      expect(l.lines, sample().lines);
    });

    test('якорь снизу справа сдвигает на разницу размеров', () {
      final StitchLayers l = StitchLayerCommands.resize(
        sample(),
        width: 6,
        height: 5,
        anchor: ResizeAnchor.bottomRight,
      );
      expect(l.partials.first.column, 2);
      expect(l.partials.first.row, 2);
      expect(l.lines.first.from, const LatticeNode(4, 4));
      expect(l.points.map((p) => p.node), const <LatticeNode>[LatticeNode(5, 5), LatticeNode(11, 9)]);
    });

    test('уменьшение обрезает: что не влезло — удаляется, линия с вышедшим концом тоже', () {
      final StitchLayers l = StitchLayerCommands.resize(sample(), width: 3, height: 2);
      expect(l.partials.single.column, 0);
      expect(l.lines.single.to, const LatticeNode(2, 0));
      expect(l.points.single.kind, PointKind.frenchKnot);
    });

    test('сдвиг в отрицательную сторону отбрасывает вышедшее за левый и верхний край', () {
      final StitchLayers l = StitchLayerCommands.resize(
        sample(),
        width: 2,
        height: 1,
        anchor: ResizeAnchor.bottomRight,
      );
      expect(l.partials.single.column, 1);
      expect(l.lines.single.from, const LatticeNode(2, 0));
      expect(l.points.single.kind, PointKind.bead);
    });
  });
}
