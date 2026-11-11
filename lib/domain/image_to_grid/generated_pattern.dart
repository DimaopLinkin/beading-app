import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/blend_suggester.dart';
import 'package:beading/domain/image_to_grid/generation_stats.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/stitch/line_stitch.dart';

/// Результат конвейера: сетка и палитра. Значение сетки `0` — пустая ячейка, `n` — `palette[n - 1]`.
final class GeneratedPattern {
  GeneratedPattern({
    required this.grid,
    required List<PaletteEntry> palette,
    this.stats,
    List<BlendSuggestion> blendSuggestions = const <BlendSuggestion>[],
    List<LineStitch> lines = const <LineStitch>[],
  }) : palette = List<PaletteEntry>.unmodifiable(palette),
       blendSuggestions = List<BlendSuggestion>.unmodifiable(blendSuggestions),
       lines = List<LineStitch>.unmodifiable(lines);

  final Grid grid;
  final List<PaletteEntry> palette;

  /// Метрики качества; считает конвейер после всех шагов. У схемы, собранной не конвейером, `null`.
  final GenerationStats? stats;

  /// Предложения бленда двух ниток (T57, только вышивка и только если запрос просил): схему они не меняют.
  final List<BlendSuggestion> blendSuggestions;

  /// Контуры-бэкстич (T49, T46): линии цвета из [palette]; значение цвета — номер записи палитры с единицы.
  final List<LineStitch> lines;
}
