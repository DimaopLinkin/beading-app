import 'package:beading/app/composition/core_module.dart';
import 'package:beading/app/library_entries.dart';
import 'package:beading/data/projects/drift_project_repository.dart';
import 'package:beading/domain/image_pattern/book_work/record_book_progress.dart';
import 'package:beading/domain/projects/project_content_cleaner.dart';
import 'package:beading/domain/projects/project_content_cloner.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/change_project_status.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/delete_project.dart';
import 'package:beading/domain/projects/use_cases/duplicate_project.dart';
import 'package:beading/domain/projects/use_cases/rename_project.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:beading/domain/projects/use_cases/update_notes.dart';
import 'package:beading/domain/projects/use_cases/watch_projects.dart';
import 'package:beading/presentation/library/library_cubit.dart';
import 'package:beading/presentation/library/new_project_entry.dart';
import 'package:beading/presentation/library/project_thumbnail_provider.dart';

/// Проекты: репозиторий и сценарии, которыми пользуются все остальные фичи (ADR-0007).
final class ProjectsModule {
  /// [cleaners] и [cloners] — содержимое всех фич, которое нужно удалить или скопировать вместе с проектом.
  /// Списки собирает корень графа лениво: модули фич создаются после проектов.
  ProjectsModule({
    required CoreModule core,
    required List<ProjectContentCleaner> Function() cleaners,
    required List<ProjectContentCloner> Function() cloners,
  }) : _core = core,
       _cleaners = cleaners,
       _cloners = cloners;

  final CoreModule _core;
  final List<ProjectContentCleaner> Function() _cleaners;
  final List<ProjectContentCloner> Function() _cloners;

  late final ProjectRepository repository = DriftProjectRepository(
    dao: _core.database.projectsDao,
    deviceIds: _core.deviceIds,
    clock: _core.clock,
  );

  CreateProject createProject() => CreateProject(repository: repository, ids: _core.ids, clock: _core.clock);

  DeleteProject deleteProject() => DeleteProject(repository, cleaners: _cleaners());

  DuplicateProject duplicateProject() =>
      DuplicateProject(repository: repository, ids: _core.ids, clock: _core.clock, cloners: _cloners());

  /// Пункты листа «Новый проект»: фичи добавляют свои в [registerLibraryEntries].
  late final NewProjectRegistry newProjectRegistry = _createRegistry();

  late final ProjectThumbnailRegistry thumbnailRegistry = ProjectThumbnailRegistry();

  LibraryCubit libraryCubit() => LibraryCubit(
    watchProjects: watchProjects(),
    deleteProject: deleteProject(),
    renameProject: renameProject(),
    duplicateProject: duplicateProject(),
  );

  RenameProject renameProject() => RenameProject(repository);

  UpdateNotes updateNotes() => UpdateNotes(repository);

  WatchProjects watchProjects() => WatchProjects(repository);

  TouchProject touchProject() => TouchProject(repository: repository, clock: _core.clock);

  ChangeProjectStatus changeProjectStatus() => ChangeProjectStatus(repository: repository, events: _core.events);

  RecordBookProgress recordBookProgress() =>
      RecordBookProgress(projects: repository, changeStatus: changeProjectStatus(), touch: touchProject());

  static NewProjectRegistry _createRegistry() {
    final NewProjectRegistry registry = NewProjectRegistry();
    registerLibraryEntries(registry);
    return registry;
  }
}
