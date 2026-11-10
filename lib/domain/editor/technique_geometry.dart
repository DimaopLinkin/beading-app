import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/projects/craft.dart';

/// Техники, которые предлагает редактор бисерных схем, в порядке показа.
const List<Technique> editorBeadingTechniques = <Technique>[Technique.loom, Technique.peyote, Technique.brick];

/// Раскладка ячеек для техники: станок и квадратный стежок — ровная сетка, мозаика — пейот, кирпичик — brick.
GridGeometry geometryForTechnique(Technique technique) => switch (technique) {
  Technique.peyote => const GridGeometry.peyote(),
  Technique.brick => const GridGeometry.brick(),
  Technique.loom ||
  Technique.square ||
  Technique.offLoom ||
  Technique.crossStitch ||
  Technique.tent => const GridGeometry.rectangular(),
};
