import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid_pattern/cell_metrics_codec.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/use_cases/validate_grid_pattern.dart';

/// Сохраняет правки схемы (сетка, палитра, форма, размер ячейки) одной записью.
/// Не пускает в хранилище схему, у которой в сетке есть цвета вне палитры или размер ячейки нельзя записать.
class SaveGridPattern {
  const SaveGridPattern(GridPatternRepository patterns) : _patterns = patterns;

  final GridPatternRepository _patterns;

  Future<Result<void>> call(GridPattern pattern) async {
    final Result<void> consistent = validateGridAgainstPalette(pattern.grid, pattern.palette);
    if (consistent case Err<void>()) {
      return consistent;
    }
    final Result<String> metrics = CellMetricsCodec.encode(pattern.metrics);
    if (metrics case Err<String>(:final Failure failure)) {
      return Err<void>(failure);
    }
    return _patterns.save(pattern);
  }
}
