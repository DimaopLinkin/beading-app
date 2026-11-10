import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';

/// Результат конвейера: сетка и палитра. Значение сетки `0` — пустая ячейка, `n` — `palette[n - 1]`.
final class GeneratedPattern {
  GeneratedPattern({required this.grid, required List<PaletteEntry> palette})
    : palette = List<PaletteEntry>.unmodifiable(palette);

  final Grid grid;
  final List<PaletteEntry> palette;
}
