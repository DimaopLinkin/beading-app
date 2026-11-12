import 'package:beading/app/composition/core_module.dart';
import 'package:beading/data/projects/drift_project_repository.dart';
import 'package:beading/domain/image_pattern/book_work/record_book_progress.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/change_project_status.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/rename_project.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:beading/domain/projects/use_cases/update_notes.dart';
import 'package:beading/domain/projects/use_cases/watch_projects.dart';

/// Проекты: репозиторий и сценарии, которыми пользуются все остальные фичи (ADR-0007).
final class ProjectsModule {
  ProjectsModule({required CoreModule core}) : _core = core;

  final CoreModule _core;

  late final ProjectRepository repository = DriftProjectRepository(
    dao: _core.database.projectsDao,
    deviceIds: _core.deviceIds,
    clock: _core.clock,
  );

  CreateProject createProject() => CreateProject(repository: repository, ids: _core.ids, clock: _core.clock);

  RenameProject renameProject() => RenameProject(repository);

  UpdateNotes updateNotes() => UpdateNotes(repository);

  WatchProjects watchProjects() => WatchProjects(repository);

  TouchProject touchProject() => TouchProject(repository: repository, clock: _core.clock);

  ChangeProjectStatus changeProjectStatus() => ChangeProjectStatus(repository: repository, events: _core.events);

  RecordBookProgress recordBookProgress() =>
      RecordBookProgress(projects: repository, changeStatus: changeProjectStatus(), touch: touchProject());
}
