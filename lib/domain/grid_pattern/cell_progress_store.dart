import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';

/// Прогресс по клеткам вышивки. Отдельно от GridProgressStore (ряды бисера): у вышивки отметки — блоки 16×16.
abstract interface class CellProgressStore {
  /// Прогресс схемы; для схемы без отметок — пустой с шириной схемы.
  Future<Result<CellProgress>> load(String patternId);

  /// Прогресс при каждом изменении.
  Stream<CellProgress> watch(String patternId);

  /// Отмечает ([done] = `true`) или снимает клетки [cells] внутри одной транзакции: две подряд посланные записи не
  /// теряют друг друга. Клетки вне ширины схемы пропускаются.
  Future<Result<void>> setCells(String patternId, Iterable<CellPosition> cells, {required bool done});

  /// Записывает блоки целиком, в одной транзакции. Пустой список байт — блок очищен. Слияние при синхронизации — по
  /// блоку, побеждает последняя запись.
  Future<Result<void>> writeBlocks(String patternId, Map<int, Uint8List> blocks);
}
