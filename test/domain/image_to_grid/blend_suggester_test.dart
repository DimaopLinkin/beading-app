import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/blend_suggester.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

GeneratedPattern _pattern(List<Rgb> palette, List<int> cells, int columns) => GeneratedPattern(
  grid: Grid.fromCells(width: columns, height: cells.length ~/ columns, cells: cells),
  palette: <PaletteEntry>[for (final Rgb c in palette) PaletteEntry(rgb: c)],
);

void main() {
  const Rgb red = Rgb(200, 40, 40);
  const Rgb yellow = Rgb(230, 200, 50);
  final Rgb orange = Rgb.average(const <Rgb>[red, yellow]);

  test('область цвета «посередине» двух ниток получает предложение бленда', () {
    final GeneratedPattern pattern = _pattern(
      const <Rgb>[red, yellow],
      <int>[for (int i = 0; i < 40; i++) i < 20 ? 1 : 2],
      10,
    );
    final List<Rgb?> photo = <Rgb?>[for (int i = 0; i < 40; i++) i < 12 ? red : (i < 28 ? orange : yellow)];
    final List<BlendSuggestion> suggestions = suggestBlends(pattern, photo, maxPairDeltaE: 120);
    expect(suggestions, hasLength(1));
    final BlendSuggestion blend = suggestions.single;
    expect((blend.first, blend.second), (0, 1));
    expect(blend.rgb, Rgb.average(const <Rgb>[red, yellow]));
    expect(blend.cells, <int>[for (int i = 12; i < 28; i++) i]);
    expect(blend.meanGain, greaterThan(2));
  });

  test('если каждая клетка совпала с цветом палитры, предложений нет', () {
    final GeneratedPattern pattern = _pattern(
      const <Rgb>[red, yellow],
      <int>[for (int i = 0; i < 40; i++) i < 20 ? 1 : 2],
      10,
    );
    final List<Rgb?> photo = <Rgb?>[for (int i = 0; i < 40; i++) i < 20 ? red : yellow];
    expect(suggestBlends(pattern, photo), isEmpty);
  });

  test('мало клеток (меньше порога) и слишком далёкие цвета — не бленд', () {
    final GeneratedPattern pattern = _pattern(
      const <Rgb>[red, yellow],
      <int>[for (int i = 0; i < 40; i++) i < 20 ? 1 : 2],
      10,
    );
    final List<Rgb?> few = <Rgb?>[for (int i = 0; i < 40; i++) i < 3 ? orange : (i < 20 ? red : yellow)];
    expect(suggestBlends(pattern, few), isEmpty);
    final List<Rgb?> photo = <Rgb?>[for (int i = 0; i < 40; i++) i < 12 ? red : (i < 28 ? orange : yellow)];
    expect(suggestBlends(pattern, photo, maxPairDeltaE: 10), isEmpty);
  });

  test('одна клетка достаётся одному предложению; не больше maxSuggestions', () {
    const Rgb blue = Rgb(40, 60, 200);
    final Rgb teal = Rgb.average(const <Rgb>[blue, yellow]);
    final GeneratedPattern pattern = _pattern(
      const <Rgb>[red, yellow, blue],
      <int>[for (int i = 0; i < 60; i++) i < 20 ? 1 : (i < 40 ? 2 : 3)],
      10,
    );
    final List<Rgb?> photo = <Rgb?>[
      for (int i = 0; i < 60; i++) i < 15 ? orange : (i < 30 ? yellow : (i < 45 ? teal : blue)),
    ];
    final List<BlendSuggestion> all = suggestBlends(pattern, photo, maxPairDeltaE: 120);
    final List<int> cells = <int>[for (final BlendSuggestion s in all) ...s.cells];
    expect(cells.length, cells.toSet().length);
    expect(suggestBlends(pattern, photo, maxPairDeltaE: 120, maxSuggestions: 1), hasLength(1));
  });
}
