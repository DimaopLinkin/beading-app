import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
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

PatternColor _floss(String hex, String code, String name, String symbol) => PatternColor(
  rgb: Rgb.fromHex(hex),
  name: name,
  components: <CatalogRef>[CatalogRef(brand: 'DMC', code: code)],
  symbol: symbol,
);

/// Палитра вышивки: тёмная, светлая, красная, зелёная, жёлтая нить (значения сетки 1–5).
PaletteSnapshot stitchPalette() => PaletteSnapshot(<PatternColor>[
  _floss('#2B2B30', '310', 'Чёрный', 'A'),
  _floss('#F4EFE6', 'B5200', 'Белый снег', 'B'),
  _floss('#C8302E', '321', 'Красный', 'C'),
  _floss('#3F8F4F', '699', 'Зелёный', 'D'),
  _floss('#F2C230', '725', 'Жёлтый', 'E'),
]);

/// Схема 14×10: контур, фон из белого и крестик-акцент, одна пустая клетка.
Grid stitchGrid() => Grid.fromCells(
  width: 14,
  height: 10,
  cells: <int>[
    for (int row = 0; row < 10; row++)
      for (int column = 0; column < 14; column++)
        if (row == 0 || row == 9 || column == 0 || column == 13)
          1
        else if (row == 5 && column == 6)
          0
        else
          <int>[2, 3, 4, 5, 2][(column + row) % 5],
  ],
);

/// Слои: бэкстич по контуру внутри рамки, по одному неполному крестику каждого вида, узелки и бусина.
StitchLayers stitchLayers() => StitchLayers(
  columns: 14,
  rows: 10,
  colorSpecs: const <int, StitchSpec>{3: StitchSpec(crossStrands: 3)},
  partials: <PartialStitch>[
    PartialStitch(column: 2, row: 2, kind: PartialKind.half, orientation: StitchOrientation.slash, color: 3),
    PartialStitch(column: 3, row: 2, kind: PartialKind.quarter, orientation: StitchOrientation.topLeft, color: 4),
    PartialStitch(
      column: 4,
      row: 2,
      kind: PartialKind.threeQuarter,
      orientation: StitchOrientation.bottomRight,
      color: 5,
    ),
    PartialStitch(column: 5, row: 2, kind: PartialKind.petit, orientation: StitchOrientation.bottomLeft, color: 3),
    PartialStitch(column: 6, row: 2, kind: PartialKind.tent, orientation: StitchOrientation.backslash, color: 1),
  ],
  lines: <LineStitch>[
    LineStitch(a: const LatticeNode(4, 8), b: const LatticeNode(24, 8), kind: LineKind.backstitch, color: 1),
    LineStitch(a: const LatticeNode(24, 8), b: const LatticeNode(24, 16), kind: LineKind.backstitch, color: 1),
    LineStitch(a: const LatticeNode(4, 8), b: const LatticeNode(14, 16), kind: LineKind.straight, color: 3),
    LineStitch(a: const LatticeNode(15, 9), b: const LatticeNode(25, 17), kind: LineKind.straight, color: 2),
  ],
  points: <PointStitch>[
    PointStitch.knot(node: const LatticeNode.center(10, 4), kind: PointKind.frenchKnot, color: 1),
    PointStitch.knot(node: const LatticeNode.center(11, 4), kind: PointKind.colonialKnot, color: 3, wraps: 3),
    PointStitch.bead(
      node: const LatticeNode.corner(12, 6),
      bead: const CatalogRef(brand: 'Miyuki', code: 'DB-0200'),
    ),
  ],
);

/// Канва кремового цвета: проверяет, что цвет канвы схемы доходит до экрана.
Fabric cream() => Fabric.standard.withColor(const Rgb(240, 228, 200));
