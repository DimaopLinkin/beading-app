import 'package:beading/domain/editor/shape_edit.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:equatable/equatable.dart';

/// Состояние схемы для истории правок: сетка и слои вышивки (неполные крестики, бэкстич, узелки).
///
/// У бисерной схемы слоёв нет: [layers] равно `null`.
final class EditorSnapshot extends Equatable {
  const EditorSnapshot({required this.grid, this.layers, this.edit});

  final Grid grid;
  final StitchLayers? layers;

  /// Правка формы, которой получено это состояние из предыдущего (для сдвига отметок прогресса при «Отменить» и
  /// «Вернуть»). В сравнение не входит.
  final ShapeEdit? edit;

  /// Копия без [edit]: следующая обычная правка формы не наследует.
  EditorSnapshot copyWith({Grid? grid, StitchLayers? layers, ShapeEdit? edit}) =>
      EditorSnapshot(grid: grid ?? this.grid, layers: layers ?? this.layers, edit: edit);

  @override
  List<Object?> get props => <Object?>[grid, layers];
}
