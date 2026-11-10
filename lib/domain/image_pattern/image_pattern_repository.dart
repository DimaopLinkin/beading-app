import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';

/// Схемы-картинки проектов. Удалённые (с надгробием) наружу не отдаёт.
abstract interface class ImagePatternRepository {
  /// [NotFoundFailure](../../core/failure.dart), если у проекта нет схемы.
  Future<Result<ImagePattern>> getByProject(String projectId);

  /// Сохраняет новую схему вместе со страницами одной записью.
  Future<Result<void>> save(ImagePattern pattern);

  /// Мягко удаляет схему проекта и её страницы. Если схемы нет — успех.
  Future<Result<void>> deleteByProject(String projectId);
}
