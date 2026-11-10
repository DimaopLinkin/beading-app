import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/materials/material_estimate.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:equatable/equatable.dart';

/// Расход бисера одного цвета.
final class BeadMaterialLine extends Equatable implements MaterialLine {
  const BeadMaterialLine({
    required this.colorIndex,
    required this.color,
    required this.pieces,
    required this.piecesWithReserve,
    required this.grams,
    required this.gramsWithReserve,
  });

  @override
  final int colorIndex;

  @override
  final PatternColor color;

  /// Бусин в схеме.
  final int pieces;

  /// Бусин с запасом, округлено вверх.
  final int piecesWithReserve;

  /// Вес бусин схемы, граммы.
  final double grams;

  /// Вес бусин с запасом, граммы.
  final double gramsWithReserve;

  @override
  List<Object?> get props => <Object?>[colorIndex, color, pieces, piecesWithReserve, grams, gramsWithReserve];
}

/// Расход бисера на схему.
final class BeadEstimate extends Equatable implements MaterialEstimate {
  BeadEstimate({required this.beadSize, required this.reserve, required List<BeadMaterialLine> lines})
    : lines = List<BeadMaterialLine>.unmodifiable(lines);

  final BeadSize beadSize;

  @override
  final double reserve;

  @override
  final List<BeadMaterialLine> lines;

  /// Всего бусин в схеме.
  int get totalPieces => lines.fold(0, (sum, l) => sum + l.pieces);

  /// Всего бусин с запасом (сумма по цветам: запас округляется для каждого цвета отдельно).
  int get totalPiecesWithReserve => lines.fold(0, (sum, l) => sum + l.piecesWithReserve);

  double get totalGrams => lines.fold(0, (sum, l) => sum + l.grams);

  double get totalGramsWithReserve => lines.fold(0, (sum, l) => sum + l.gramsWithReserve);

  @override
  List<Object?> get props => <Object?>[beadSize, reserve, lines];
}

/// Расход бисера: штуки по цветам, граммы по весу бусины размера [beadSize] и запас [reserve].
final class BeadEstimator implements MaterialEstimator {
  BeadEstimator({required this.beadSize, this.reserve = defaultReserve}) {
    if (!reserve.isFinite || reserve < 0 || reserve > 1) {
      throw ArgumentError.value(reserve, 'reserve', 'доля от 0 до 1');
    }
  }

  /// Запас по умолчанию: +10%.
  static const double defaultReserve = 0.1;

  final BeadSize beadSize;

  /// Запас, доля (`0.1` — 10%).
  final double reserve;

  @override
  BeadEstimate estimate(Grid grid, PaletteSnapshot palette) {
    final List<int> counts = List<int>.filled(palette.length + 1, 0);
    for (final int value in grid.cells) {
      if (value == 0) continue;
      if (value > palette.length) {
        throw ArgumentError('В схеме цвет $value, а в палитре ${palette.length} цветов');
      }
      counts[value]++;
    }
    return BeadEstimate(
      beadSize: beadSize,
      reserve: reserve,
      lines: <BeadMaterialLine>[
        for (int value = 1; value <= palette.length; value++)
          if (counts[value] > 0) _line(value, palette.colors[value - 1], counts[value]),
      ],
    );
  }

  BeadMaterialLine _line(int colorIndex, PatternColor color, int pieces) {
    // Относительная поправка: 10 × 1,1 в double — 11,000000000000002, и «потолок» дал бы лишнюю бусину; ошибка растёт
    // вместе с числом бусин (до 16,7 млн), поэтому поправка пропорциональна.
    final double exact = pieces * (1 + reserve);
    final int withReserve = (exact - exact * 1e-12).ceil();
    return BeadMaterialLine(
      colorIndex: colorIndex,
      color: color,
      pieces: pieces,
      piecesWithReserve: withReserve,
      grams: pieces * beadSize.weightGrams,
      gramsWithReserve: withReserve * beadSize.weightGrams,
    );
  }
}
