import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:beading/domain/stitch/point_stitch.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_spec.dart';
import 'package:flutter_test/flutter_test.dart';

PatternColor _gamma(String code, String name, Rgb rgb) => PatternColor(
  rgb: rgb,
  name: name,
  components: <CatalogRef>[CatalogRef(brand: 'Гамма', code: code)],
);

final PatternColor _red = _gamma('3071', 'Красный', const Rgb(200, 0, 0));
final PatternColor _blue = _gamma('3095', 'Синий', const Rgb(0, 0, 200));
final PatternColor _blend = PatternColor(
  rgb: const Rgb(100, 0, 100),
  name: 'Смесь',
  components: const <CatalogRef>[
    CatalogRef(brand: 'Гамма', code: '3071'),
    CatalogRef(brand: 'Гамма', code: '3095'),
  ],
);

Grid _grid(int width, int height, List<int> cells) => Grid.fromCells(width: width, height: height, cells: cells);

/// Аида 14 на белом: клетка 25,4 / 14 = 1,814 мм.
const Fabric _aida14 = Fabric.standard;

void main() {
  const double cell = 25.4 / 14;

  group('FlossEstimator', () {
    test('полные крестики: k × клетка × сложения, 100 крестиков в 2 сложения', () {
      final Grid grid = _grid(10, 10, List<int>.filled(100, 1));
      final FlossEstimate estimate = FlossEstimator(
        fabric: _aida14,
        layers: StitchLayers.empty(columns: 10, rows: 10),
        reserve: 0,
      ).estimate(grid, PaletteSnapshot(<PatternColor>[_red]));

      // 100 × 7 × 1,814 мм × 2 сложения = 2,54 м одной нити.
      expect(estimate.lines.single.crossStitches, 100);
      expect(estimate.lines.single.strandMeters, closeTo(100 * 7 * cell * 2 / 1000, 1e-9));
      expect(estimate.lines.single.skeins, 1);
      expect(estimate.purchases.single.ref, const CatalogRef(brand: 'Гамма', code: '3071'));
      expect(estimate.purchases.single.name, 'Красный');
    });

    test('мотки: малый расход — один моток, 10 000 крестиков — несколько', () {
      final Grid small = _grid(1, 1, <int>[1]);
      final FlossEstimate one = FlossEstimator(
        fabric: _aida14,
        layers: StitchLayers.empty(columns: 1, rows: 1),
      ).estimate(small, PaletteSnapshot(<PatternColor>[_red]));
      expect(one.lines.single.skeins, 1);
      expect(one.lines.single.skeinsWithReserve, 1);

      // 100 × 100 = 10 000 крестиков в 2 сложения: 10 000 × 7 × 1,814 × 2 / 1000 ≈ 254 м одной нити = 5,3 мотка.
      final FlossEstimate big = FlossEstimator(
        fabric: _aida14,
        layers: StitchLayers.empty(columns: 100, rows: 100),
        reserve: 0,
      ).estimate(_grid(100, 100, List<int>.filled(10000, 1)), PaletteSnapshot(<PatternColor>[_red]));
      expect(big.lines.single.skeins, 6);
      expect(big.purchases.single.skeins, 6);
    });

    test('запас увеличивает расход и мотки', () {
      final Grid grid = _grid(100, 100, List<int>.filled(10000, 1));
      final FlossEstimate estimate = FlossEstimator(
        fabric: _aida14,
        layers: StitchLayers.empty(columns: 100, rows: 100),
        reserve: 0.2,
      ).estimate(grid, PaletteSnapshot(<PatternColor>[_red]));

      final FlossMaterialLine line = estimate.lines.single;
      expect(line.strandMetersWithReserve, closeTo(line.strandMeters * 1.2, 1e-9));
      // 254 × 1,2 = 305 м / 48 = 6,4 → 7.
      expect(line.skeinsWithReserve, 7);
      expect(estimate.totalSkeinsWithReserve, 7);
    });

    test('неполные крестики, бэкстич и узелки добавляют нитки; бусины слоя не считаются', () {
      final StitchLayers layers = StitchLayers(
        columns: 2,
        rows: 2,
        partials: <PartialStitch>[
          PartialStitch(column: 0, row: 0, kind: PartialKind.half, orientation: StitchOrientation.slash, color: 2),
          PartialStitch(
            column: 1,
            row: 0,
            kind: PartialKind.threeQuarter,
            orientation: StitchOrientation.topLeft,
            color: 2,
          ),
        ],
        lines: <LineStitch>[
          // Две клетки по горизонтали (4 шага решётки) и диагональ клетки (2 шага по обеим осям).
          LineStitch(a: const LatticeNode(0, 0), b: const LatticeNode(4, 0), kind: LineKind.backstitch, color: 2),
          LineStitch(a: const LatticeNode(0, 2), b: const LatticeNode(2, 4), kind: LineKind.backstitch, color: 2),
        ],
        points: <PointStitch>[
          PointStitch.knot(node: const LatticeNode(1, 1), kind: PointKind.frenchKnot, color: 2),
          PointStitch.bead(
            node: const LatticeNode(3, 3),
            bead: const CatalogRef(brand: 'Toho', code: '1'),
          ),
        ],
      );
      final FlossEstimate estimate = FlossEstimator(
        fabric: _aida14,
        layers: layers,
        reserve: 0,
      ).estimate(_grid(2, 2, <int>[0, 0, 0, 0]), PaletteSnapshot(<PatternColor>[_red, _blue]));

      expect(estimate.lines.map((l) => l.colorIndex), <int>[2]);
      final FlossMaterialLine line = estimate.lines.single;
      expect(line.crossStitches, 0);
      expect(line.partialStitches, 2);
      expect(line.knots, 1);
      expect(line.backstitchCells, closeTo(2 + 1.4142135623730951, 1e-9));
      const double expected =
          (0.5 + 0.75) * 7 * cell * 2 + // неполные, 2 сложения
          (2 + 1.4142135623730951) * 2 * cell * 1 + // бэкстич, 1 сложение
          (2 + 2) * cell * 2; // узелок: основа 2 + 2 оборота, 2 сложения
      expect(line.strandMeters, closeTo(expected / 1000, 1e-9));
    });

    test('сложения цвета переопределяют сложения схемы', () {
      final StitchLayers layers = StitchLayers(
        columns: 1,
        rows: 1,
        colorSpecs: const <int, StitchSpec>{1: StitchSpec(crossStrands: 1)},
      );
      final FlossEstimate estimate = FlossEstimator(
        fabric: _aida14,
        layers: layers,
        reserve: 0,
      ).estimate(_grid(1, 1, <int>[1]), PaletteSnapshot(<PatternColor>[_red]));

      expect(estimate.lines.single.strandMeters, closeTo(7 * cell / 1000, 1e-12));
    });

    test('смешанная нить делится поровну и складывается с одиночными в списке покупок', () {
      final FlossEstimate estimate = FlossEstimator(
        fabric: _aida14,
        layers: StitchLayers.empty(columns: 3, rows: 1),
        reserve: 0,
      ).estimate(_grid(3, 1, <int>[1, 3, 3]), PaletteSnapshot(<PatternColor>[_red, _blue, _blend]));

      // Красный 1 крестик, смесь 2 крестика: по 1 крестику каждой нитки смеси.
      expect(estimate.lines.map((l) => l.colorIndex), <int>[1, 3]);
      expect(estimate.purchases.map((p) => p.ref.code), <String>['3071', '3095']);
      const double perCross = 7 * cell * 2 / 1000;
      expect(estimate.purchases[0].strandMeters, closeTo(perCross + perCross, 1e-9));
      expect(estimate.purchases[1].strandMeters, closeTo(perCross, 1e-9));
      // 3095 встречается только в смеси: название не берём, образец — цвет смеси.
      expect(estimate.purchases[1].name, isNull);
      expect(estimate.purchases[0].name, 'Красный');
    });

    test('покупки: номера сортируются по значению, бренды по алфавиту, мотков не меньше одного', () {
      final PatternColor a = _gamma('3095', 'А', const Rgb(1, 1, 1));
      final PatternColor b = _gamma('307', 'Б', const Rgb(2, 2, 2));
      final PatternColor c = PatternColor(
        rgb: const Rgb(3, 3, 3),
        name: 'В',
        components: const <CatalogRef>[CatalogRef(brand: 'DMC', code: '310')],
      );
      final FlossEstimate estimate = FlossEstimator(
        fabric: _aida14,
        layers: StitchLayers.empty(columns: 3, rows: 1),
      ).estimate(_grid(3, 1, <int>[1, 2, 3]), PaletteSnapshot(<PatternColor>[a, b, c]));

      expect(estimate.purchases.map((p) => '${p.ref.brand} ${p.ref.code}'), <String>[
        'DMC 310',
        'Гамма 307',
        'Гамма 3095',
      ]);
      expect(estimate.purchases.every((p) => p.skeins == 1 && p.skeinsWithReserve == 1), isTrue);
      expect(estimate.totalSkeins, 3);
    });

    test('канва: размер вышивки и кусок с полями', () {
      final FlossEstimate estimate = FlossEstimator(
        fabric: _aida14,
        layers: StitchLayers.empty(columns: 14, rows: 28),
      ).estimate(_grid(14, 28, List<int>.filled(14 * 28, 1)), PaletteSnapshot(<PatternColor>[_red]));

      // 14 клеток Аиды 14 — 1 дюйм = 2,54 см; 28 клеток — 5,08 см; поля по 5 см.
      expect(estimate.fabricNeed.stitchedWidthCm, closeTo(2.54, 1e-9));
      expect(estimate.fabricNeed.stitchedHeightCm, closeTo(5.08, 1e-9));
      expect(estimate.fabricNeed.widthCm, closeTo(12.54, 1e-9));
      expect(estimate.fabricNeed.heightCm, closeTo(15.08, 1e-9));
    });

    test('пустая схема — нет строк и покупок', () {
      final FlossEstimate estimate = FlossEstimator(
        fabric: _aida14,
        layers: StitchLayers.empty(columns: 2, rows: 1),
      ).estimate(_grid(2, 1, <int>[0, 0]), PaletteSnapshot(<PatternColor>[_red]));

      expect(estimate.lines, isEmpty);
      expect(estimate.purchases, isEmpty);
      expect(estimate.totalSkeins, 0);
    });

    test('ошибки: цвет вне палитры, слои не по размеру сетки, плохой запас', () {
      expect(
        () => FlossEstimator(
          fabric: _aida14,
          layers: StitchLayers.empty(columns: 1, rows: 1),
        ).estimate(_grid(1, 1, <int>[2]), PaletteSnapshot(<PatternColor>[_red])),
        throwsArgumentError,
      );
      expect(
        () => FlossEstimator(
          fabric: _aida14,
          layers: StitchLayers.empty(columns: 2, rows: 1),
        ).estimate(_grid(1, 1, <int>[1]), PaletteSnapshot(<PatternColor>[_red])),
        throwsArgumentError,
      );
      expect(
        () => FlossEstimator(fabric: _aida14, layers: StitchLayers.empty(columns: 1, rows: 1), reserve: 2),
        throwsArgumentError,
      );
    });
  });
}
