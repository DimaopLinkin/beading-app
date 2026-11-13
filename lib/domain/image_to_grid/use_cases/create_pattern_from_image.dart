import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/palette_from_generated.dart';
import 'package:beading/domain/image_to_grid/technique_geometry.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_layers_codec.dart';
import 'package:beading/domain/stitch/stitch_spec.dart';

/// Сохраняет результат конвейера как сеточный проект в выбранной технике: бисерный или вышивку (T46).
///
/// У вышивки контуры-бэкстич ([GeneratedPattern.lines]) сохраняются слоем, а число сложений берётся из канвы.
class CreatePatternFromImage {
  const CreatePatternFromImage(CreateGridPattern createGridPattern) : _create = createGridPattern;

  final CreateGridPattern _create;

  Future<Result<Project>> call({
    required String name,
    required Technique technique,
    required CellMetrics metrics,
    required GeneratedPattern pattern,
  }) async {
    final Result<PaletteSnapshot> palette = paletteFromGenerated(pattern);
    if (palette case Err<PaletteSnapshot>(:final Failure failure)) {
      return Err<Project>(failure);
    }
    final Result<CreatedGridPattern> created = await _create(
      name: name,
      metrics: metrics,
      width: pattern.grid.width,
      height: pattern.grid.height,
      craft: technique.craft,
      technique: technique,
      geometry: geometryForTechnique(technique),
      grid: pattern.grid,
      palette: palette.valueOrNull,
      layers: _layers(pattern, technique, metrics),
    );
    return switch (created) {
      Success<CreatedGridPattern>(:final CreatedGridPattern value) => Success<Project>(value.project),
      Err<CreatedGridPattern>(:final Failure failure) => Err<Project>(failure),
    };
  }

  /// Слои вышивки: у вышивки всегда (число сложений по канве и линии контуров, если есть).
  GridLayersBlob? _layers(GeneratedPattern pattern, Technique technique, CellMetrics metrics) {
    if (technique.craft != Craft.crossStitch) return null;
    final StitchSpec spec = metrics is Fabric
        ? StitchSpec(crossStrands: metrics.defaultCrossStrands, backstitchStrands: metrics.defaultBackstitchStrands)
        : const StitchSpec();
    return StitchLayersCodec.toBlob(
      StitchLayers(
        columns: pattern.grid.width,
        rows: pattern.grid.height,
        defaultSpec: spec,
        lines: pattern.lines,
      ),
    );
  }
}
