import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/domain/materials/use_cases/load_project_floss.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum FlossStatus { loading, ready, failure }

class FlossState extends Equatable {
  const FlossState({
    this.status = FlossStatus.loading,
    this.projectName = '',
    this.estimate,
    this.failure,
    this.withReserve = false,
  });

  final FlossStatus status;
  final String projectName;
  final FlossEstimate? estimate;
  final Failure? failure;

  /// Показывать мотки с запасом (в списках, итоге и тексте «Поделиться»).
  final bool withReserve;

  bool get isEmpty => estimate != null && estimate!.lines.isEmpty;

  FlossState copyWith({bool? withReserve}) => FlossState(
    status: status,
    projectName: projectName,
    estimate: estimate,
    failure: failure,
    withReserve: withReserve ?? this.withReserve,
  );

  @override
  List<Object?> get props => <Object?>[status, projectName, estimate, failure, withReserve];
}

/// Расход мулине проекта-вышивки: нитки по цветам, список покупок и канва.
class FlossCubit extends Cubit<FlossState> {
  FlossCubit({required this.projectId, required LoadProjectFloss loadFloss, required ProjectRepository projects})
    : _loadFloss = loadFloss,
      _projects = projects,
      super(const FlossState());

  final String projectId;
  final LoadProjectFloss _loadFloss;
  final ProjectRepository _projects;

  Future<void> load() async {
    emit(const FlossState());
    final Result<Project> project = await _projects.get(projectId);
    if (isClosed) return;
    if (project case Err<Project>(:final Failure failure)) {
      emit(FlossState(status: FlossStatus.failure, failure: failure));
      return;
    }
    final Result<FlossEstimate> estimate = await _loadFloss(projectId);
    if (isClosed) return;
    final String name = project.valueOrNull?.name ?? '';
    switch (estimate) {
      case Success<FlossEstimate>(:final FlossEstimate value):
        emit(FlossState(status: FlossStatus.ready, projectName: name, estimate: value));
      case Err<FlossEstimate>(:final Failure failure):
        emit(FlossState(status: FlossStatus.failure, projectName: name, failure: failure));
    }
  }

  void setWithReserve({required bool value}) => emit(state.copyWith(withReserve: value));
}
