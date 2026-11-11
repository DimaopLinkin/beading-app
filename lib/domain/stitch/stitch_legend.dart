import 'dart:math' as math;

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:beading/domain/stitch/point_stitch.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_spec.dart';
import 'package:equatable/equatable.dart';

/// Строка легенды вышивки: цвет палитры и сколько стежков им сделано.
///
/// Счёт стежков, сложения нити и, если передан расчёт мулине, число мотков цвета.
final class StitchLegendEntry extends Equatable {
  const StitchLegendEntry({
    required this.gridValue,
    required this.color,
    required this.spec,
    required this.crosses,
    required this.partials,
    required this.backstitchLength,
    required this.knots,
    this.skeins,
  });

  /// Значение сетки: `palette[gridValue - 1]`.
  final int gridValue;
  final PatternColor color;

  /// Сложения нити для этого цвета.
  final StitchSpec spec;

  /// Полных крестиков.
  final int crosses;

  /// Неполных крестиков (½, ¼, ¾, петит, гобеленовых).
  final int partials;

  /// Бэкстич и прямые стежки, в клетках (диагональ по решётке считается как `√2` полушага).
  final double backstitchLength;

  /// Узелков.
  final int knots;

  /// Мотков на этот цвет (без запаса), если легенду строили с расчётом мулине; иначе `null`.
  ///
  /// У смешанной нити — условно по цвету целиком, в магазин ходят по списку покупок `FlossEstimate.purchases`.
  final int? skeins;

  /// Цвет нигде не используется.
  bool get isUnused => crosses == 0 && partials == 0 && backstitchLength == 0 && knots == 0;

  @override
  List<Object?> get props => <Object?>[gridValue, color, spec, crosses, partials, backstitchLength, knots, skeins];
}

/// Собирает строки легенды по схеме, палитре и слоям вышивки.
///
/// Порядок строк — порядок палитры, цвета без единого стежка остаются в списке (в схеме их мог ещё не использовать
/// редактор), экран сам решает, показывать ли их.
abstract final class StitchLegend {
  static List<StitchLegendEntry> build({
    required Grid grid,
    required PaletteSnapshot palette,
    StitchLayers? layers,
    FlossEstimate? floss,
  }) {
    final List<int> crosses = List<int>.filled(palette.length + 1, 0);
    for (final int value in grid.cells) {
      if (value >= 1 && value <= palette.length) crosses[value]++;
    }
    final List<int> partials = List<int>.filled(palette.length + 1, 0);
    final List<double> lengths = List<double>.filled(palette.length + 1, 0);
    final List<int> knots = List<int>.filled(palette.length + 1, 0);
    if (layers != null) {
      for (final PartialStitch p in layers.partials) {
        if (p.color <= palette.length) partials[p.color]++;
      }
      for (final LineStitch l in layers.lines) {
        if (l.color > palette.length) continue;
        lengths[l.color] += math.sqrt(math.pow(l.to.x - l.from.x, 2) + math.pow(l.to.y - l.from.y, 2)) / 2;
      }
      for (final PointStitch p in layers.points) {
        if (p.kind != PointKind.bead && p.color <= palette.length) knots[p.color]++;
      }
    }
    final Map<int, int> skeinsByColor = <int, int>{
      if (floss != null)
        for (final FlossMaterialLine line in floss.lines) line.colorIndex: line.skeins,
    };
    return <StitchLegendEntry>[
      for (int value = 1; value <= palette.length; value++)
        StitchLegendEntry(
          gridValue: value,
          color: palette.colorAt(value)!,
          spec: layers?.specFor(value) ?? const StitchSpec(),
          crosses: crosses[value],
          partials: partials[value],
          backstitchLength: lengths[value],
          knots: knots[value],
          skeins: skeinsByColor[value],
        ),
    ];
  }
}
