import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/blend_suggester.dart';
import 'package:beading/domain/image_to_grid/frame_planner.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';

/// Поля вокруг готовой схемы (T88a): последний дешёвый шаг конвейера.
abstract final class PatternFrame {
  /// Ставит внутреннюю сетку [pattern] в пустую сетку [columns] × [rows] со смещением из [plan]. Контуры, неполные
  /// крестики и клетки блендов сдвигаются вместе с ней; палитра и метрики остаются как есть (метрики считаются по
  /// внутренней сетке). Без полей возвращает [pattern] как есть.
  static GeneratedPattern pad(GeneratedPattern pattern, FramePlan plan, int columns, int rows) {
    final Grid inner = pattern.grid;
    final int dx = plan.offsetColumn;
    final int dy = plan.offsetRow;
    if (columns > Grid.maxSide || rows > Grid.maxSide) {
      throw ArgumentError('Схема с полями больше ${Grid.maxSide} клеток');
    }
    if (dx < 0 || dy < 0 || dx + inner.width > columns || dy + inner.height > rows) {
      throw ArgumentError(
        'Внутренняя сетка ${inner.width}×${inner.height} не помещается в $columns×$rows со смещением',
      );
    }
    if (columns == inner.width && rows == inner.height) return pattern;

    final Uint16List cells = Uint16List(columns * rows);
    final Uint16List source = inner.cells;
    for (int row = 0; row < inner.height; row++) {
      cells.setRange((row + dy) * columns + dx, (row + dy) * columns + dx + inner.width, source, row * inner.width);
    }
    return GeneratedPattern(
      grid: Grid.fromCells(width: columns, height: rows, cells: cells),
      palette: pattern.palette,
      stats: pattern.stats,
      blendSuggestions: <BlendSuggestion>[
        for (final BlendSuggestion b in pattern.blendSuggestions)
          BlendSuggestion(
            first: b.first,
            second: b.second,
            rgb: b.rgb,
            cells: <int>[
              for (final int cell in b.cells) (cell ~/ inner.width + dy) * columns + cell % inner.width + dx,
            ],
            meanGain: b.meanGain,
          ),
      ],
      lines: <LineStitch>[
        for (final LineStitch l in pattern.lines)
          LineStitch(a: l.from.shifted(2 * dx, 2 * dy), b: l.to.shifted(2 * dx, 2 * dy), kind: l.kind, color: l.color),
      ],
      partials: <PartialStitch>[
        for (final PartialStitch p in pattern.partials) p.copyWith(column: p.column + dx, row: p.row + dy),
      ],
    );
  }
}
