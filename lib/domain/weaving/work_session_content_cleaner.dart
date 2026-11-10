import 'package:beading/core/result.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_content_cleaner.dart';
import 'package:beading/domain/weaving/work_session_repository.dart';

/// Убирает сессии работы удалённого проекта; нужен проектам любого вида содержимого.
class WorkSessionContentCleaner implements ProjectContentCleaner {
  const WorkSessionContentCleaner(this._sessions);

  final WorkSessionRepository _sessions;

  @override
  bool supports(ContentKind kind) => true;

  @override
  Future<Result<void>> remove(Project project) => _sessions.deleteByProject(project.id);
}
