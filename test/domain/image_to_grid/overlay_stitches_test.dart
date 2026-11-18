import 'dart:typed_data';

import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/overlay_stitches.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';

const int _columns = 10;
const int _rows = 6;
const Rgb _dark = Rgb(90, 90, 90);
const Rgb _light = Rgb(150, 150, 150);
const Rgb _between = Rgb(122, 122, 122);

GeneratedPattern _pattern({List<PaletteEntry>? palette}) => GeneratedPattern(
  grid: Grid.fromCells(
    width: _columns,
    height: _rows,
    cells: <int>[for (int i = 0; i < _columns * _rows; i++) i % _columns < 5 ? 1 : 2],
  ),
  palette: palette ?? <PaletteEntry>[const PaletteEntry(rgb: _dark), const PaletteEntry(rgb: _light)],
);

/// Фото: слева тёмный, справа светлый, а у границы (столбцы 4 и 5) цвет посередине.
List<Rgb?> _photo() => <Rgb?>[
  for (int i = 0; i < _columns * _rows; i++)
    switch (i % _columns) {
      4 || 5 => _between,
      < 4 => _dark,
      _ => _light,
    },
];

void main() {
  test('у перехода между двумя нитками появляются полукресты другой нитки поверх крестов', () {
    final List<PartialStitch> partials = suggestOverlays(_pattern(), _photo(), maxPairDeltaE: 40);
    expect(partials, isNotEmpty);
    for (final PartialStitch p in partials) {
      expect(p.kind, PartialKind.half);
      expect(p.orientation, StitchOrientation.slash);
      expect(p.column, anyOf(4, 5), reason: 'только на границе, где цвет фото между нитками');
      // Поверх тёмного креста (столбец 4) — светлая нитка и наоборот.
      expect(p.color, p.column == 4 ? 2 : 1);
    }
  });

  test('одиночная клетка без соседей с тем же полукрестом отбрасывается', () {
    final List<Rgb?> photo = <Rgb?>[for (int i = 0; i < _columns * _rows; i++) i % _columns < 5 ? _dark : _light];
    photo[2 * _columns + 4] = _between;
    expect(suggestOverlays(_pattern(), photo, maxPairDeltaE: 40), isEmpty);
  });

  test('клетки вне объекта и из пропускаемых не получают полукрестов', () {
    final Uint8List none = Uint8List(_columns * _rows);
    expect(suggestOverlays(_pattern(), _photo(), subject: none, maxPairDeltaE: 40), isEmpty);
    final Set<int> all = <int>{for (int i = 0; i < _columns * _rows; i++) i};
    expect(suggestOverlays(_pattern(), _photo(), skip: all, maxPairDeltaE: 40), isEmpty);
  });

  test('бленд-цвета не участвуют ни как нижний, ни как верхний', () {
    final CatalogColor partner = catalogColor('310', 'Нитка', '#000000', material: CatalogMaterial.floss);
    final GeneratedPattern blended = _pattern(
      palette: <PaletteEntry>[
        PaletteEntry(rgb: _dark, blendPartner: partner),
        PaletteEntry(rgb: _light, blendPartner: partner),
      ],
    );
    expect(suggestOverlays(blended, _photo(), maxPairDeltaE: 40), isEmpty);
  });

  test('доля клеток ограничена', () {
    final List<PartialStitch> partials = suggestOverlays(_pattern(), _photo(), maxPairDeltaE: 40, maxShare: 0.1);
    expect(partials.length, lessThanOrEqualTo((_columns * _rows * 0.1).floor()));
  });

  test('слишком далёкие нитки не смешиваются', () {
    expect(suggestOverlays(_pattern(), _photo(), maxPairDeltaE: 5), isEmpty);
  });
}
