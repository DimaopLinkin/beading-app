import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_spec.dart';

/// Расход мулине для ещё не сохранённой схемы мастера: тот же расчёт, что у проекта, по сетке и контурам схемы.
///
/// `null`, если схема не на канве (бисер) или палитра не сходится с сеткой.
FlossEstimate? estimateFlossForGenerated(GeneratedPattern pattern, PaletteSnapshot palette, CellMetrics metrics) {
  if (metrics is! Fabric) return null;
  final StitchLayers layers = StitchLayers(
    columns: pattern.grid.width,
    rows: pattern.grid.height,
    defaultSpec: StitchSpec(
      crossStrands: metrics.defaultCrossStrands,
      backstitchStrands: metrics.defaultBackstitchStrands,
    ),
    lines: pattern.lines,
  );
  try {
    return FlossEstimator(fabric: metrics, layers: layers).estimate(pattern.grid, palette);
  } on ArgumentError {
    return null;
  }
}
