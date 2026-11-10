import 'package:beading/core/result.dart';
import 'package:beading/domain/projects/project.dart';

/// Убирает за удалённым проектом то, что лежит вне таблицы проектов (файлы, строки содержимого).
/// Реализации подключают задачи с содержимым: каждая отвечает за свой [ContentKind].
abstract interface class ProjectContentCleaner {
  bool supports(ContentKind kind);

  Future<Result<void>> remove(Project project);
}
