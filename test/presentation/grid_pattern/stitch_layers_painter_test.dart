import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:beading/domain/stitch/point_stitch.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_spec.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/grid_pattern/stitch_layers_painter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'grid_fixtures.dart';

const ui.Color _surface = ui.Color(0xFFFFFFFF);

final GridScene _scene = GridScene(
  geometry: const GridGeometry.rectangular(),
  metrics: Fabric.standard,
  columns: 4,
  rows: 4,
);

// Размер клетки 22 пикселя; цвета палитры: 1 — золотой, 2 — коралловый, 3 — синий.
const double _cell = 22;

StitchLayersStyle _style({
  Set<StitchLayerKind> hidden = const <StitchLayerKind>{},
  int? highlight,
  bool realistic = false,
}) => StitchLayersStyle(
  surface: _surface,
  unknown: const ui.Color(0xFFC7C7CC),
  hiddenLayers: hidden,
  highlightColor: highlight,
  realistic: realistic,
);

/// Цвет пикселя слоёв по координатам сцены; `null` — прозрачно.
Future<ui.Color?> _render(
  WidgetTester tester,
  StitchLayers layers,
  List<ui.Offset> probes, {
  StitchLayersStyle? style,
}) async {
  final PaletteSnapshot palette = samplePalette();
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  StitchLayersPaint.paint(
    ui.Canvas(recorder),
    scene: _scene,
    layers: layers,
    palette: palette,
    style: style ?? _style(),
  );
  final ui.Picture picture = recorder.endRecording();
  final ui.Color? hit = await tester.runAsync<ui.Color?>(() async {
    final ui.Image image = await picture.toImage(_scene.size.width.ceil(), _scene.size.height.ceil());
    final ByteData data = (await image.toByteData())!;
    for (final ui.Offset p in probes) {
      final int i = ((p.dy.floor() * image.width) + p.dx.floor()) * 4;
      final ui.Color c = ui.Color.fromARGB(
        data.getUint8(i + 3),
        data.getUint8(i),
        data.getUint8(i + 1),
        data.getUint8(i + 2),
      );
      if (c.a > 0.01) return c;
    }
    return null;
  });
  return hit;
}

StitchLayers _layers({
  Iterable<PartialStitch> partials = const <PartialStitch>[],
  Iterable<LineStitch> lines = const <LineStitch>[],
  Iterable<PointStitch> points = const <PointStitch>[],
  StitchSpec spec = const StitchSpec(),
}) => StitchLayers(columns: 4, rows: 4, defaultSpec: spec, partials: partials, lines: lines, points: points);

LineStitch _line(LatticeNode a, LatticeNode b, {int color = 3}) =>
    LineStitch(a: a, b: b, kind: LineKind.backstitch, color: color);

const ui.Color _blue = ui.Color(0xFF2F5DA8);

void main() {
  group('бэкстич', () {
    testWidgets('рисуется цветом нити по линии решётки', (tester) async {
      // Горизонталь по верхней границе второго ряда: между узлами (2, 2) и (6, 2).
      final ui.Color? c = await _render(
        tester,
        _layers(lines: <LineStitch>[_line(const LatticeNode(2, 2), const LatticeNode(6, 2))]),
        <ui.Offset>[const ui.Offset(_cell * 2, _cell + 0.5)],
      );
      expect(c, _blue);
    });

    testWidgets('на канве пусто там, где стежка нет', (tester) async {
      final ui.Color? c = await _render(
        tester,
        _layers(lines: <LineStitch>[_line(const LatticeNode(2, 2), const LatticeNode(6, 2))]),
        <ui.Offset>[const ui.Offset(_cell * 2, _cell * 3)],
      );
      expect(c, isNull);
    });

    testWidgets('идёт через середины клеток по полушаговой решётке', (tester) async {
      // Диагональ из центра клетки (0, 0) в центр клетки (1, 1).
      final ui.Color? c = await _render(
        tester,
        _layers(lines: <LineStitch>[_line(const LatticeNode.center(0, 0), const LatticeNode.center(1, 1))]),
        <ui.Offset>[const ui.Offset(_cell, _cell)],
      );
      expect(c, _blue);
    });

    testWidgets('слой можно скрыть', (tester) async {
      final ui.Color? c = await _render(
        tester,
        _layers(lines: <LineStitch>[_line(const LatticeNode(2, 2), const LatticeNode(6, 2))]),
        <ui.Offset>[const ui.Offset(_cell * 2, _cell + 0.5)],
        style: _style(hidden: const <StitchLayerKind>{StitchLayerKind.lines}),
      );
      expect(c, isNull);
    });

    testWidgets('толще при большем числе сложений', (tester) async {
      Future<ui.Color?> at(int strands, double dy) => _render(
        tester,
        _layers(
          lines: <LineStitch>[_line(const LatticeNode(0, 4), const LatticeNode(8, 4))],
          spec: StitchSpec(backstitchStrands: strands),
        ),
        <ui.Offset>[ui.Offset(_cell * 2, _cell * 2 + dy)],
      );
      // 1 сложение: ширина ≈ 0,09 клетки, значит на 1,6 пикселя от оси линия уже не рисуется; 4 сложения: ≈ 0,18.
      expect(await at(1, 1.4), isNot(_blue));
      expect(await at(4, 1.4), _blue);
    });
  });

  group('неполные крестики', () {
    PartialStitch partial(PartialKind kind, StitchOrientation o) =>
        PartialStitch(column: 1, row: 1, kind: kind, orientation: o, color: 3);

    testWidgets('полукрестик «/» проходит через центр клетки и не задевает «чужой» угол', (tester) async {
      final StitchLayers layers = _layers(
        partials: <PartialStitch>[partial(PartialKind.half, StitchOrientation.slash)],
      );
      expect(await _render(tester, layers, <ui.Offset>[const ui.Offset(_cell * 1.5, _cell * 1.5)]), _blue);
      // Левый верхний угол клетки на другой диагонали.
      expect(await _render(tester, layers, <ui.Offset>[const ui.Offset(_cell + 3, _cell + 3)]), isNull);
    });

    testWidgets('четверть идёт от угла к центру, дальнего угла не задевает', (tester) async {
      final StitchLayers layers = _layers(
        partials: <PartialStitch>[partial(PartialKind.quarter, StitchOrientation.topLeft)],
      );
      expect(await _render(tester, layers, <ui.Offset>[const ui.Offset(_cell + 6, _cell + 6)]), _blue);
      expect(await _render(tester, layers, <ui.Offset>[const ui.Offset(_cell * 2 - 4, _cell * 2 - 4)]), isNull);
    });

    testWidgets('¾ — полная диагональ и четверть от угла', (tester) async {
      final StitchLayers layers = _layers(
        partials: <PartialStitch>[partial(PartialKind.threeQuarter, StitchOrientation.topLeft)],
      );
      // Диагональ «/» (через центр к правому верхнему углу) и четверть из левого верхнего угла.
      expect(await _render(tester, layers, <ui.Offset>[const ui.Offset(_cell * 1.8, _cell * 1.2)]), _blue);
      expect(await _render(tester, layers, <ui.Offset>[const ui.Offset(_cell + 6, _cell + 6)]), _blue);
      expect(await _render(tester, layers, <ui.Offset>[const ui.Offset(_cell * 2 - 4, _cell * 2 - 4)]), isNull);
    });

    testWidgets('петит живёт в четверти клетки у своего угла', (tester) async {
      final StitchLayers layers = _layers(
        partials: <PartialStitch>[partial(PartialKind.petit, StitchOrientation.topLeft)],
      );
      expect(await _render(tester, layers, <ui.Offset>[const ui.Offset(_cell + 5.5, _cell + 5.5)]), _blue);
      expect(await _render(tester, layers, <ui.Offset>[const ui.Offset(_cell * 2 - 4, _cell * 2 - 4)]), isNull);
    });

    testWidgets('гобеленовый стежок идёт по диагонали клетки', (tester) async {
      final StitchLayers layers = _layers(
        partials: <PartialStitch>[partial(PartialKind.tent, StitchOrientation.backslash)],
      );
      expect(await _render(tester, layers, <ui.Offset>[const ui.Offset(_cell * 1.5, _cell * 1.5)]), _blue);
    });

    testWidgets('скрывается отдельно от бэкстича', (tester) async {
      final StitchLayers layers = _layers(
        partials: <PartialStitch>[partial(PartialKind.half, StitchOrientation.slash)],
        lines: <LineStitch>[_line(const LatticeNode(0, 0), const LatticeNode(8, 0))],
      );
      final ui.Color? c = await _render(
        tester,
        layers,
        <ui.Offset>[const ui.Offset(_cell * 1.5, _cell * 1.5)],
        style: _style(hidden: const <StitchLayerKind>{StitchLayerKind.partials}),
      );
      expect(c, isNull);
    });
  });

  group('узелки и бусины', () {
    testWidgets('узелок — круг цвета нити в узле решётки', (tester) async {
      final ui.Color? c = await _render(
        tester,
        _layers(
          points: <PointStitch>[
            PointStitch.knot(node: const LatticeNode.center(2, 2), kind: PointKind.frenchKnot, color: 3),
          ],
        ),
        const <ui.Offset>[ui.Offset(_cell * 2.5 + 2, _cell * 2.5 + 2)],
      );
      expect(c, _blue);
    });

    testWidgets('бусина рисуется нейтральной: каталог бисера схема не знает', (tester) async {
      final ui.Color? c = await _render(
        tester,
        _layers(
          points: <PointStitch>[
            PointStitch.bead(
              node: const LatticeNode.corner(2, 2),
              bead: const CatalogRef(brand: 'Miyuki', code: 'DB-0200'),
            ),
          ],
        ),
        const <ui.Offset>[ui.Offset(_cell * 2 + 2.2, _cell * 2 - 2.2)],
      );
      expect(c, isNotNull);
      expect(c, isNot(_blue));
    });

    testWidgets('скрываются вместе, отдельно от остального', (tester) async {
      final ui.Color? c = await _render(
        tester,
        _layers(
          points: <PointStitch>[
            PointStitch.knot(node: const LatticeNode.center(2, 2), kind: PointKind.colonialKnot, color: 3, wraps: 3),
          ],
        ),
        <ui.Offset>[const ui.Offset(_cell * 2.5, _cell * 2.5)],
        style: _style(hidden: const <StitchLayerKind>{StitchLayerKind.points}),
      );
      expect(c, isNull);
    });
  });

  group('подсветка цвета', () {
    testWidgets('не подсвеченный цвет притушен к подложке, подсвеченный не меняется', (tester) async {
      final StitchLayers layers = _layers(lines: <LineStitch>[_line(const LatticeNode(2, 2), const LatticeNode(6, 2))]);
      final List<ui.Offset> probe = <ui.Offset>[const ui.Offset(_cell * 2, _cell + 0.5)];
      expect(await _render(tester, layers, probe, style: _style(highlight: 3)), _blue);
      final ui.Color? dimmed = await _render(tester, layers, probe, style: _style(highlight: 1));
      expect(dimmed, isNotNull);
      expect(dimmed, isNot(_blue));
      // Притушенный ближе к белой подложке, чем к синему.
      expect(dimmed!.g, greaterThan(_blue.g));
    });
  });

  testWidgets('в реалистичном виде вместо каймы у линии тень, сдвинутая вниз', (tester) async {
    final StitchLayers layers = _layers(lines: <LineStitch>[_line(const LatticeNode(2, 2), const LatticeNode(6, 2))]);
    const List<ui.Offset> above = <ui.Offset>[ui.Offset(_cell * 2 + 4, 20.5)];
    const List<ui.Offset> below = <ui.Offset>[ui.Offset(_cell * 2 + 4, 23.5)];
    expect(await _render(tester, layers, above), isNotNull, reason: 'кайма плоского вида');
    expect(await _render(tester, layers, above, style: _style(realistic: true)), isNull);
    expect(await _render(tester, layers, below, style: _style(realistic: true)), isNotNull);
  });

  group('кеш слоя', () {
    final StitchLayers layers = _layers(lines: <LineStitch>[_line(const LatticeNode(2, 2), const LatticeNode(6, 2))]);

    void configure(StitchLayerCache cache, {StitchLayers? l, StitchLayersStyle? style}) {
      cache.configure(layers: l ?? layers, palette: samplePalette(), scene: _scene, style: style ?? _style());
    }

    testWidgets('строит один раз, пока ничего не менялось', (tester) async {
      final StitchLayerCache cache = StitchLayerCache();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      expect(cache.configure(layers: layers, palette: samplePalette(), scene: _scene, style: _style()), isTrue);
      cache
        ..paint(canvas)
        ..paint(canvas);
      expect(cache.buildCount, 1);
      // Те же данные, но равные, а не те же объекты.
      expect(
        cache.configure(
          layers: _layers(lines: <LineStitch>[_line(const LatticeNode(2, 2), const LatticeNode(6, 2))]),
          palette: samplePalette(),
          scene: _scene,
          style: _style(),
        ),
        isFalse,
      );
      cache.paint(canvas);
      expect(cache.buildCount, 1);
      recorder.endRecording().dispose();
      cache.dispose();
    });

    testWidgets('пересобирается при смене слоёв, вида или подсветки', (tester) async {
      final StitchLayerCache cache = StitchLayerCache();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      configure(cache);
      cache.paint(canvas);
      configure(cache, style: _style(highlight: 2));
      cache.paint(canvas);
      configure(cache, style: _style(hidden: const <StitchLayerKind>{StitchLayerKind.lines}));
      cache.paint(canvas);
      configure(cache, l: _layers(lines: <LineStitch>[_line(const LatticeNode(0, 0), const LatticeNode(2, 0))]));
      cache.paint(canvas);
      expect(cache.buildCount, 4);
      recorder.endRecording().dispose();
      cache.dispose();
    });

    testWidgets('пустые слои ничего не строят', (tester) async {
      final StitchLayerCache cache = StitchLayerCache();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      configure(cache, l: _layers());
      cache.paint(ui.Canvas(recorder));
      expect(cache.buildCount, 0);
      recorder.endRecording().dispose();
      cache.dispose();
    });
  });

  test('стиль слоёв равен по значению', () {
    expect(
      _style(hidden: const <StitchLayerKind>{StitchLayerKind.lines}),
      _style(hidden: const <StitchLayerKind>{StitchLayerKind.lines}),
    );
    expect(_style(), isNot(_style(highlight: 1)));
    expect(_style().hashCode, _style().hashCode);
  });

  test('кайма контрастна нити', () {
    expect(StitchLayersPaint.halo(const ui.Color(0xFF101010)).computeLuminance(), greaterThan(0.9));
    expect(StitchLayersPaint.halo(const ui.Color(0xFFFFFFFF)).computeLuminance(), lessThan(0.1));
  });
}
