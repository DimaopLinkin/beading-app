import 'package:beading/core/result.dart';
import 'package:beading/domain/stats/load_project_stats.dart';
import 'package:beading/domain/stats/project_stats.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ProjectStatsStatus { loading, ready, failed }

class ProjectStatsState extends Equatable {
  const ProjectStatsState({this.status = ProjectStatsStatus.loading, this.stats});

  final ProjectStatsStatus status;
  final ProjectStats? stats;

  @override
  List<Object?> get props => <Object?>[status, stats];
}

/// Лист «Статистика проекта».
class ProjectStatsCubit extends Cubit<ProjectStatsState> {
  ProjectStatsCubit({required String projectId, required LoadProjectStats load})
    : _projectId = projectId,
      _load = load,
      super(const ProjectStatsState());

  final String _projectId;
  final LoadProjectStats _load;

  Future<void> load() async {
    final Result<ProjectStats> result = await _load(_projectId);
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<ProjectStats>(:final ProjectStats value):
        emit(ProjectStatsState(status: ProjectStatsStatus.ready, stats: value));
      case Err<ProjectStats>():
        emit(const ProjectStatsState(status: ProjectStatsStatus.failed));
    }
  }
}
