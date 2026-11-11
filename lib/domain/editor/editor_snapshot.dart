import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:equatable/equatable.dart';

/// Состояние схемы для истории правок: сетка и слои вышивки (неполные крестики, бэкстич, узелки).
///
/// У бисерной схемы слоёв нет: [layers] равно `null`.
final class EditorSnapshot extends Equatable {
  const EditorSnapshot({required this.grid, this.layers});

  final Grid grid;
  final StitchLayers? layers;

  EditorSnapshot copyWith({Grid? grid, StitchLayers? layers}) =>
      EditorSnapshot(grid: grid ?? this.grid, layers: layers ?? this.layers);

  @override
  List<Object?> get props => <Object?>[grid, layers];
}
