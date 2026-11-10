import 'package:beading/core/result.dart';
import 'package:beading/domain/projects/project.dart';

/// Хранилище проектов. Удалённые (с надгробием) наружу не отдаёт.
abstract interface class ProjectRepository {
  /// Все живые проекты: сначала те, над которыми работали позже. Ошибки хранилища приходят как ошибки потока.
  Stream<List<Project>> watchAll();

  /// [NotFoundFailure](../../core/failure.dart), если проекта нет или он удалён.
  Future<Result<Project>> get(String id);

  /// Создаёт проект или обновляет существующий. Для удалённого — `NotFoundFailure`.
  Future<Result<void>> save(Project project);

  /// Мягкое удаление. Для отсутствующего — `NotFoundFailure`.
  Future<Result<void>> delete(String id);
}
