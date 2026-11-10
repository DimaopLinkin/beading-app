import 'dart:async';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_filter.dart';
import 'package:beading/domain/projects/use_cases/delete_project.dart';
import 'package:beading/domain/projects/use_cases/duplicate_project.dart';
import 'package:beading/domain/projects/use_cases/rename_project.dart';
import 'package:beading/domain/projects/use_cases/watch_projects.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum LibraryStatus { loading, ready, failure }

class LibraryState extends Equatable {
  const LibraryState({
    this.status = LibraryStatus.loading,
    this.projects = const <Project>[],
    this.filter = ProjectFilter.all,
    this.actionFailure,
  });

  final LibraryStatus status;

  /// Все живые проекты, недавние первыми, без учёта фильтра.
  final List<Project> projects;
  final ProjectFilter filter;

  /// Ошибка последнего действия (удаление, переименование, дублирование); экран показывает её один раз.
  final Failure? actionFailure;

  /// Проекты, подходящие под [filter].
  List<Project> get visible => projects.where(filter.matches).toList(growable: false);

  bool get hasProjects => projects.isNotEmpty;

  bool get hasActiveFilter => filter.craft != null || filter.status != null || filter.query.trim().isNotEmpty;

  /// Проекты есть, но фильтр ничего не оставил.
  bool get hasNoMatches => status == LibraryStatus.ready && hasProjects && visible.isEmpty;

  LibraryState copyWith({
    LibraryStatus? status,
    List<Project>? projects,
    ProjectFilter? filter,
    Failure? Function()? actionFailure,
  }) => LibraryState(
    status: status ?? this.status,
    projects: projects ?? this.projects,
    filter: filter ?? this.filter,
    actionFailure: actionFailure == null ? this.actionFailure : actionFailure(),
  );

  @override
  List<Object?> get props => <Object?>[status, projects, filter, actionFailure];
}

/// Состояние экрана «Мои работы»: список, поиск и фильтры, действия над проектами.
///
/// Список всегда берётся целиком, а фильтруется здесь: так экран отличает «проектов ещё нет» от «ничего не нашлось».
class LibraryCubit extends Cubit<LibraryState> {
  LibraryCubit({
    required WatchProjects watchProjects,
    required DeleteProject deleteProject,
    required RenameProject renameProject,
    required DuplicateProject duplicateProject,
  }) : _watchProjects = watchProjects,
       _deleteProject = deleteProject,
       _renameProject = renameProject,
       _duplicateProject = duplicateProject,
       super(const LibraryState());

  final WatchProjects _watchProjects;
  final DeleteProject _deleteProject;
  final RenameProject _renameProject;
  final DuplicateProject _duplicateProject;
  StreamSubscription<List<Project>>? _subscription;

  /// Подписывается на список проектов. Повторный вызов заменяет прежнюю подписку.
  void start() {
    // Не ждём cancel: поток `async*` с `await for` отвечает на него только после следующего события.
    unawaited(_subscription?.cancel());
    _subscription = _watchProjects().listen(
      (projects) => emit(state.copyWith(status: LibraryStatus.ready, projects: projects)),
      onError: (Object _) => emit(state.copyWith(status: LibraryStatus.failure)),
    );
  }

  void retry() {
    emit(state.copyWith(status: LibraryStatus.loading));
    start();
  }

  void setQuery(String query) => emit(
    state.copyWith(
      filter: ProjectFilter(craft: state.filter.craft, status: state.filter.status, query: query),
    ),
  );

  /// Выбирает ремесло; повторное нажатие на выбранное снимает фильтр.
  void toggleCraft(Craft craft) => emit(
    state.copyWith(
      filter: ProjectFilter(
        craft: state.filter.craft == craft ? null : craft,
        status: state.filter.status,
        query: state.filter.query,
      ),
    ),
  );

  /// Выбирает статус; повторное нажатие на выбранный снимает фильтр.
  void toggleStatus(ProjectStatus status) => emit(
    state.copyWith(
      filter: ProjectFilter(
        craft: state.filter.craft,
        status: state.filter.status == status ? null : status,
        query: state.filter.query,
      ),
    ),
  );

  void clearFilters() => emit(state.copyWith(filter: ProjectFilter.all));

  Future<void> delete(String id) async => _report(await _deleteProject(id));

  Future<void> rename(String id, String name) async => _report(await _renameProject(id, name));

  Future<void> duplicate(String id) async => _report(await _duplicateProject(id));

  void acknowledgeActionFailure() => emit(state.copyWith(actionFailure: () => null));

  void _report(Result<Object?> result) {
    if (isClosed) {
      return;
    }
    if (result case Err<Object?>(:final Failure failure)) {
      emit(state.copyWith(actionFailure: () => failure));
    }
  }

  @override
  Future<void> close() {
    unawaited(_subscription?.cancel());
    return super.close();
  }
}
