import 'package:beading/core/result.dart';
import 'package:beading/domain/floss_stock/floss_stock_entry.dart';
import 'package:beading/domain/palette/catalog_ref.dart';

/// Запас мулине: какие нитки куплены и сколько мотков примерно осталось. Общий для всех проектов.
abstract interface class FlossStockRepository {
  /// Запас при каждом изменении: нитки по бренду и номеру, без нулевых.
  Stream<List<FlossStockEntry>> watchAll();

  /// Весь запас сейчас.
  Future<Result<List<FlossStockEntry>>> all();

  /// Запоминает, что ниток [ref] осталось [skeins] мотков (дробное — начатый моток). Ноль и меньше убирает нитку из
  /// запаса. Конечное число до [maxSkeins], иначе `ValidationFailure`.
  Future<Result<void>> setSkeins(CatalogRef ref, double skeins);

  /// Сливает запас из файла: нитки без записи добавляются, у остальных остаётся запись с более свежим `updatedAt`
  /// (при равенстве побеждает локальная). Записи без `updatedAt` или с неверным числом мотков пропускаются.
  /// Убранные нитки не передаются: «нет в запасе» не стирает запись на другом устройстве.
  Future<Result<void>> merge(List<FlossStockEntry> incoming);

  /// Предел одной записи, мотков: защита от опечатки.
  static const double maxSkeins = 999;
}
