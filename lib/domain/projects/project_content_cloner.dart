import 'package:beading/core/result.dart';
import 'package:beading/domain/projects/project.dart';

/// Копирует содержимое проекта при дублировании. Реализации подключают задачи с содержимым
/// (фото страницы, сетка): каждая отвечает за свой [ContentKind].
abstract interface class ProjectContentCloner {
  bool supports(ContentKind kind);

  /// Копирует содержимое [source] в уже созданный проект [targetId].
  Future<Result<void>> clone({required Project source, required String targetId});
}
