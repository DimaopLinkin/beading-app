import 'package:beading/core/result.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';

/// Прогресс по рядам. Отдельный интерфейс, а не часть репозитория схем: T38 добавит прогресс по клеткам вышивки,
/// не трогая хранилище схем.
abstract interface class GridProgressStore {
  /// Прогресс схемы; для схемы без отметок — пустой.
  Future<Result<GridProgress>> load(String patternId);

  /// Прогресс при каждом изменении.
  Stream<GridProgress> watch(String patternId);

  /// Отмечает ряд выполненным. Повторная отметка ничего не меняет.
  Future<Result<void>> markRow(String patternId, int row);

  /// Снимает отметку с ряда. Если ряд не отмечен — успех.
  Future<Result<void>> unmarkRow(String patternId, int row);

  /// Запоминает «остановилась здесь»; `bead == null` — только ряд.
  Future<Result<void>> setCurrent(String patternId, {required int row, int? bead});
}
