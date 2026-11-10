import 'package:beading/core/result.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';

/// Сеточные схемы проектов. Удалённые (с надгробием) наружу не отдаёт.
abstract interface class GridPatternRepository {
  /// [NotFoundFailure](../../core/failure.dart), если у проекта нет схемы.
  Future<Result<GridPattern>> getByProject(String projectId);

  /// То же, но без чтения сетки и палитры.
  Future<Result<GridPatternSummary>> summaryByProject(String projectId);

  /// Схема проекта сразу и при каждом изменении; `null`, пока схемы нет. Ошибки хранилища приходят ошибками потока.
  Stream<GridPattern?> watchByProject(String projectId);

  /// Записывает схему целиком: сетку, форму, размер ячейки и палитру — одной транзакцией. Новую создаёт, существующую
  /// (тот же `id`) заменяет; при ошибке старая запись остаётся нетронутой. Прогресс не меняет, но отметки рядов
  /// ниже новой высоты схемы снимает. Слои записываются ровно такими, какие в [GridPattern]: правящий схему код
  /// обязан передавать прочитанные слои обратно (`null` стирает их).
  Future<Result<void>> save(GridPattern pattern);

  /// Мягко удаляет схему проекта вместе с палитрой и прогрессом. Если схемы нет — успех.
  Future<Result<void>> deleteByProject(String projectId);
}
