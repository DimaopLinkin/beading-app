import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';

PatternColor _color(String hex, String code, String symbol, {String? finish}) => PatternColor(
  rgb: Rgb.fromHex(hex),
  name: code,
  components: <CatalogRef>[CatalogRef(brand: 'Miyuki', code: code)],
  finish: finish,
  symbol: symbol,
);

/// Палитра из пяти цветов: золотой и коралловый (на них сливалось кольцо), синий, белый и чёрный.
PaletteSnapshot samplePalette() => PaletteSnapshot(<PatternColor>[
  _color('#F2B84B', 'DB-0031', 'A', finish: 'luster'),
  _color('#E8664D', 'DB-0722', 'B', finish: 'matte'),
  _color('#2F5DA8', 'DB-0728', 'C', finish: 'metallic'),
  _color('#FFFFFF', 'DB-0200', 'D', finish: 'transparent'),
  _color('#101010', 'DB-0010', 'E'),
]);

/// Детерминированная сетка с пустыми ячейками.
Grid sampleGrid({int width = 12, int height = 10}) => Grid.fromCells(
  width: width,
  height: height,
  cells: <int>[for (int i = 0; i < width * height; i++) (i * 7 + i ~/ width) % 6],
);
