import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/blend_suggester.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';

/// Превращает предложения бленда (T57) в цвета схемы (T46): каждое предложение — новая запись палитры «две нитки в
/// иголке», клетки предложения перекрашиваются в неё. Нитки, которые после этого нигде не используются, убираются.
///
/// Предложение пропускается, если одна из его ниток не из каталога (бленд собирается только из ниток каталога) или
/// палитра переполнилась бы. Остальные поля [pattern] (метрики, предложения) сохраняются, линии не переносятся: их
/// строят после бленда по итоговой палитре.
GeneratedPattern applyBlends(GeneratedPattern pattern, List<BlendSuggestion> suggestions) {
  final List<PaletteEntry> palette = List<PaletteEntry>.of(pattern.palette);
  final Uint16List cells = Uint16List.fromList(pattern.grid.cells);
  int applied = 0;
  for (final BlendSuggestion blend in suggestions) {
    final PaletteEntry first = pattern.palette[blend.first];
    final PaletteEntry second = pattern.palette[blend.second];
    final catalogFirst = first.catalog;
    final catalogSecond = second.catalog;
    if (catalogFirst == null || catalogSecond == null || first.blendPartner != null || second.blendPartner != null) {
      continue;
    }
    if (palette.length >= PaletteSnapshot.maxColors) break;
    palette.add(PaletteEntry(rgb: blend.rgb, catalog: catalogFirst, blendPartner: catalogSecond));
    final int index = palette.length;
    for (final int cell in blend.cells) {
      if (cells[cell] != 0) cells[cell] = index;
    }
    applied++;
  }
  if (applied == 0) return pattern;

  final Set<int> used = <int>{
    for (final int v in cells)
      if (v != 0) v,
  };
  final Map<int, int> remap = <int, int>{};
  final List<PaletteEntry> kept = <PaletteEntry>[];
  for (int i = 0; i < palette.length; i++) {
    if (used.contains(i + 1)) {
      kept.add(palette[i]);
      remap[i + 1] = kept.length;
    }
  }
  for (int i = 0; i < cells.length; i++) {
    if (cells[i] != 0) cells[i] = remap[cells[i]]!;
  }
  return GeneratedPattern(
    grid: Grid.fromCells(width: pattern.grid.width, height: pattern.grid.height, cells: cells),
    palette: kept,
    stats: pattern.stats,
    // Номера в предложениях относятся к палитре до бленда: годятся как счётчик, но не как индексы.
    blendSuggestions: pattern.blendSuggestions,
  );
}
