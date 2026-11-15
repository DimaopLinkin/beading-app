import 'package:beading/core/result.dart';
import 'package:beading/domain/bead_stock/bead_stock_entry.dart';
import 'package:beading/domain/palette/catalog_ref.dart';

/// Запас бисера: какие цвета куплены и сколько граммов примерно осталось. Общий для всех проектов.
/// Ссылка — бренд и артикул, как в палитре схемы (серия и размер в неё не входят).
abstract interface class BeadStockRepository {
  /// Запас при каждом изменении: цвета по бренду и артикулу, без нулевых.
  Stream<List<BeadStockEntry>> watchAll();

  /// Весь запас сейчас.
  Future<Result<List<BeadStockEntry>>> all();

  /// Запоминает, что бисера [ref] осталось [grams] граммов. Ноль и меньше убирает цвет из запаса. Конечное число до [maxGrams], иначе `ValidationFailure`.
  Future<Result<void>> setGrams(CatalogRef ref, double grams);

  /// Сливает запас из файла: цвета без записи добавляются, у остальных остаётся запись с более свежим `updatedAt`
  /// (при равенстве побеждает локальная). Записи без `updatedAt` или с неверным числом граммов пропускаются.
  /// Убранные цвета не передаются: «нет в запасе» не стирает запись на другом устройстве.
  Future<Result<void>> merge(List<BeadStockEntry> incoming);

  /// Предел одной записи, граммов: защита от опечатки.
  static const double maxGrams = 9999;
}
