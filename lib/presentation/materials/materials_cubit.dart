import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/materials/bead_estimate.dart';
import 'package:beading/domain/materials/use_cases/load_project_materials.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum MaterialsStatus { loading, ready, failure }

class MaterialsState extends Equatable {
  const MaterialsState({
    this.status = MaterialsStatus.loading,
    this.projectName = '',
    this.estimate,
    this.failure,
    this.withReserve = false,
  });

  final MaterialsStatus status;
  final String projectName;
  final BeadEstimate? estimate;
  final Failure? failure;

  /// Показывать количество с запасом (в таблице, итогах и тексте «Поделиться»).
  final bool withReserve;

  bool get isEmpty => estimate != null && estimate!.lines.isEmpty;

  MaterialsState copyWith({
    MaterialsStatus? status,
    String? projectName,
    BeadEstimate? estimate,
    Failure? failure,
    bool? withReserve,
  }) => MaterialsState(
    status: status ?? this.status,
    projectName: projectName ?? this.projectName,
    estimate: estimate ?? this.estimate,
    failure: failure ?? this.failure,
    withReserve: withReserve ?? this.withReserve,
  );

  @override
  List<Object?> get props => <Object?>[status, projectName, estimate, failure, withReserve];
}

/// Материалы проекта: расход бисера по цветам схемы.
class MaterialsCubit extends Cubit<MaterialsState> {
  MaterialsCubit({
    required this.projectId,
    required LoadProjectMaterials loadMaterials,
    required ProjectRepository projects,
  }) : _loadMaterials = loadMaterials,
       _projects = projects,
       super(const MaterialsState());

  final String projectId;
  final LoadProjectMaterials _loadMaterials;
  final ProjectRepository _projects;

  Future<void> load() async {
    emit(const MaterialsState());
    final Result<Project> project = await _projects.get(projectId);
    if (isClosed) return;
    if (project case Err<Project>(:final Failure failure)) {
      emit(MaterialsState(status: MaterialsStatus.failure, failure: failure));
      return;
    }
    final Result<BeadEstimate> estimate = await _loadMaterials(projectId);
    if (isClosed) return;
    final String name = project.valueOrNull?.name ?? '';
    switch (estimate) {
      case Success<BeadEstimate>(:final BeadEstimate value):
        emit(MaterialsState(status: MaterialsStatus.ready, projectName: name, estimate: value));
      case Err<BeadEstimate>(:final Failure failure):
        emit(MaterialsState(status: MaterialsStatus.failure, projectName: name, failure: failure));
    }
  }

  void setWithReserve({required bool value}) => emit(state.copyWith(withReserve: value));
}
