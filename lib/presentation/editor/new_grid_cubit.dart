import 'package:beading/core/result.dart';
import 'package:beading/domain/editor/technique_geometry.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/mm.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NewGridState extends Equatable {
  const NewGridState({
    this.name = '',
    this.technique = Technique.loom,
    this.width = 10,
    this.height = 40,
    this.bead = BeadSize.delica11,
    this.creating = false,
    this.failed = false,
    this.projectId,
  });

  /// Допустимый размер схемы в бусинах по каждой стороне.
  static const int minSide = 1;
  static const int maxSide = 500;

  final String name;
  final Technique technique;
  final int width;
  final int height;
  final BeadSize bead;
  final bool creating;
  final bool failed;

  /// Созданный проект: экран закрывается с ним.
  final String? projectId;

  bool get validSize => width >= minSide && width <= maxSide && height >= minSide && height <= maxSide;

  /// Размер готового изделия, мм (с учётом раскладки техники).
  MmSize get sizeMm => geometryForTechnique(technique).extent(bead, columns: width, rows: height);

  NewGridState copyWith({
    String? name,
    Technique? technique,
    int? width,
    int? height,
    BeadSize? bead,
    bool? creating,
    bool? failed,
    String? projectId,
  }) => NewGridState(
    name: name ?? this.name,
    technique: technique ?? this.technique,
    width: width ?? this.width,
    height: height ?? this.height,
    bead: bead ?? this.bead,
    creating: creating ?? this.creating,
    failed: failed ?? this.failed,
    projectId: projectId ?? this.projectId,
  );

  @override
  List<Object?> get props => <Object?>[name, technique, width, height, bead, creating, failed, projectId];
}

/// Лист создания схемы: техника, размер в бусинах, бисер. Создаёт пустую схему и проект.
class NewGridCubit extends Cubit<NewGridState> {
  NewGridCubit({required CreateGridPattern createPattern, required this.defaultName})
    : _create = createPattern,
      super(const NewGridState());

  final CreateGridPattern _create;

  /// Название, если пользовательница ничего не ввела.
  final String defaultName;

  void setName(String value) => emit(state.copyWith(name: value));

  void setTechnique(Technique value) => emit(state.copyWith(technique: value));

  void setBead(BeadSize value) => emit(state.copyWith(bead: value));

  void setWidth(int value) => emit(state.copyWith(width: value));

  void setHeight(int value) => emit(state.copyWith(height: value));

  Future<void> create() async {
    if (state.creating || !state.validSize) return;
    emit(state.copyWith(creating: true, failed: false));
    final String name = state.name.trim().isEmpty ? defaultName : state.name.trim();
    final Result<CreatedGridPattern> result = await _create(
      name: name,
      metrics: state.bead,
      width: state.width.clamp(1, Grid.maxSide),
      height: state.height.clamp(1, Grid.maxSide),
      technique: state.technique,
      geometry: geometryForTechnique(state.technique),
    );
    switch (result) {
      case Success<CreatedGridPattern>(:final CreatedGridPattern value):
        emit(state.copyWith(creating: false, projectId: value.project.id));
      case Err<CreatedGridPattern>():
        emit(state.copyWith(creating: false, failed: true));
    }
  }
}
