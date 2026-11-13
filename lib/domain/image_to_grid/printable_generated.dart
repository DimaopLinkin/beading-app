import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_layers_codec.dart';
import 'package:beading/domain/stitch/stitch_spec.dart';

/// Схема мастера в виде `GridPattern`, чтобы напечатать её до сохранения; `null`, если схема не на канве.
GridPattern? printablePatternOf(GeneratedPattern pattern, PaletteSnapshot palette, CellMetrics metrics) {
  if (metrics is! Fabric) return null;
  return GridPattern(
    id: 'draft',
    projectId: 'draft',
    geometry: const GridGeometry.rectangular(),
    metrics: metrics,
    grid: pattern.grid,
    palette: palette.withLegibleSymbols(),
    layers: StitchLayersCodec.toBlob(
      StitchLayers(
        columns: pattern.grid.width,
        rows: pattern.grid.height,
        defaultSpec: StitchSpec(
          crossStrands: metrics.defaultCrossStrands,
          backstitchStrands: metrics.defaultBackstitchStrands,
        ),
        lines: pattern.lines,
      ),
    ),
  );
}
