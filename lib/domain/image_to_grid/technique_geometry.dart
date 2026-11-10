import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/projects/craft.dart';

/// Как ячейки схемы лежат в технике: пейот и кирпичный стежок со сдвигом, остальные — ровными рядами.
GridGeometry geometryForTechnique(Technique technique) => switch (technique) {
  Technique.peyote => const GridGeometry.peyote(),
  Technique.brick => const GridGeometry.brick(),
  Technique.loom ||
  Technique.square ||
  Technique.offLoom ||
  Technique.crossStitch ||
  Technique.tent => const GridGeometry.rectangular(),
};
