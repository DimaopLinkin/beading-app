import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/grid_progress_store.dart';

typedef _Action = Future<Result<void>> Function(GridPatternSummary summary);

Future<Result<void>> _onPattern(GridPatternRepository patterns, String projectId, _Action action) async {
  final Result<GridPatternSummary> found = await patterns.summaryByProject(projectId);
  return switch (found) {
    Err<GridPatternSummary>(:final Failure failure) => Err<void>(failure),
    Success<GridPatternSummary>(:final GridPatternSummary value) => action(value),
  };
}

Result<void> _checkRow(GridPatternSummary summary, int row) => row < 0 || row >= summary.readingRowCount
    ? Err<void>(ValidationFailure('Ряда $row нет в схеме из ${summary.readingRowCount} рядов'))
    : const Success<void>(null);

/// Отмечает ряд схемы выполненным.
class MarkRow {
  const MarkRow({required GridPatternRepository patterns, required GridProgressStore progress})
    : _patterns = patterns,
      _progress = progress;

  final GridPatternRepository _patterns;
  final GridProgressStore _progress;

  Future<Result<void>> call({required String projectId, required int row}) => _onPattern(
    _patterns,
    projectId,
    (summary) async {
      final Result<void> checked = _checkRow(summary, row);
      return checked is Err<void> ? checked : _progress.markRow(summary.id, row);
    },
  );
}

/// Снимает отметку с ряда.
class UnmarkRow {
  const UnmarkRow({required GridPatternRepository patterns, required GridProgressStore progress})
    : _patterns = patterns,
      _progress = progress;

  final GridPatternRepository _patterns;
  final GridProgressStore _progress;

  Future<Result<void>> call({required String projectId, required int row}) => _onPattern(
    _patterns,
    projectId,
    (summary) async {
      final Result<void> checked = _checkRow(summary, row);
      return checked is Err<void> ? checked : _progress.unmarkRow(summary.id, row);
    },
  );
}

/// Запоминает ряд и бусину, на которых остановились.
class SetCurrentBead {
  const SetCurrentBead({required GridPatternRepository patterns, required GridProgressStore progress})
    : _patterns = patterns,
      _progress = progress;

  final GridPatternRepository _patterns;
  final GridProgressStore _progress;

  Future<Result<void>> call({required String projectId, required int row, int? bead}) => _onPattern(
    _patterns,
    projectId,
    (summary) async {
      final Result<void> checked = _checkRow(summary, row);
      if (checked is Err<void>) {
        return checked;
      }
      if (bead != null && (bead < 0 || bead >= summary.maxRowLength)) {
        return Err<void>(ValidationFailure('Бусины $bead нет в ряду из ${summary.maxRowLength} бусин'));
      }
      return _progress.setCurrent(summary.id, row: row, bead: bead);
    },
  );
}
