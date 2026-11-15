import 'package:beading/core/result.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/steps_progress.dart';

/// Пошаговые инструкции проектов. Удалённые (с надгробием) наружу не отдаёт.
abstract interface class StepPatternRepository {
  /// [NotFoundFailure](../../core/failure.dart), если у проекта нет инструкции.
  /// Документ новее поддерживаемого — [ValidationFailure](../../core/failure.dart).
  Future<Result<StepPattern>> getByProject(String projectId);

  /// Создаёт или заменяет инструкцию одной транзакцией: документ и список картинок ([StepPattern.images]).
  /// Картинки, которых в списке больше нет, помечаются удалёнными (сами файлы убирает вызывающий).
  Future<Result<void>> save(StepPattern pattern);

  /// Мягко удаляет инструкцию проекта, её картинки и прогресс. Если инструкции нет — успех.
  Future<Result<void>> deleteByProject(String projectId);
}

/// Курсор прогресса по инструкции.
abstract interface class StepsProgressStore {
  /// Курсор или `null`, если работу ещё не начинали.
  Future<Result<StepsProgress?>> load(String patternId);

  Future<Result<void>> save(String patternId, StepsProgress progress);
}
