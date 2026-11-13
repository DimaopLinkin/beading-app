import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/editor/cell_rect.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/cell_progress_store.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';

/// Общая часть команд отметки: находит схему, считает новый прогресс и пишет только изменившиеся блоки.
abstract class _MarkCommand {
  const _MarkCommand({required GridPatternRepository patterns, required CellProgressStore progress})
    : _patterns = patterns,
      _progress = progress;

  final GridPatternRepository _patterns;
  final CellProgressStore _progress;

  /// Клетки, которые нужно отметить, по сетке; пустые клетки схемы отбрасываются.
  Future<Result<void>> run(
    String projectId, {
    required bool done,
    required Result<Iterable<CellPosition>> Function(GridPattern pattern) pick,
  }) async {
    final Result<GridPattern> found = await _patterns.getByProject(projectId);
    if (found case Err<GridPattern>(:final Failure failure)) {
      return Err<void>(failure);
    }
    final GridPattern pattern = found.valueOrNull!;
    final Result<Iterable<CellPosition>> picked = pick(pattern);
    if (picked case Err<Iterable<CellPosition>>(:final Failure failure)) {
      return Err<void>(failure);
    }
    return _progress.setCells(
      pattern.id,
      picked.valueOrNull!.where((c) => pattern.grid.at(c.column, c.row) != 0),
      done: done,
    );
  }
}

bool _inside(Grid grid, CellPosition c) => c.column >= 0 && c.row >= 0 && c.column < grid.width && c.row < grid.height;

/// Отмечает (или снимает отметку) с клетки или мазка из нескольких клеток. Клетки вне схемы — ошибка проверки.
class MarkCells extends _MarkCommand {
  const MarkCells({required super.patterns, required super.progress});

  Future<Result<void>> call({required String projectId, required List<CellPosition> cells, required bool done}) => run(
    projectId,
    done: done,
    pick: (pattern) {
      final Grid grid = pattern.grid;
      for (final CellPosition c in cells) {
        if (!_inside(grid, c)) {
          return Err<Iterable<CellPosition>>(ValidationFailure('Клетки $c нет в схеме ${grid.width}×${grid.height}'));
        }
      }
      return Success<Iterable<CellPosition>>(cells);
    },
  );
}

/// Отмечает или снимает отметку с прямоугольной области; часть области за схемой обрезается.
class MarkRect extends _MarkCommand {
  const MarkRect({required super.patterns, required super.progress});

  Future<Result<void>> call({required String projectId, required CellRect rect, required bool done}) => run(
    projectId,
    done: done,
    pick: (pattern) {
      final Grid grid = pattern.grid;
      final CellRect? clipped = rect.clipTo(grid);
      if (clipped == null) {
        return const Err<Iterable<CellPosition>>(ValidationFailure('Область целиком за пределами схемы'));
      }
      return Success<Iterable<CellPosition>>(<CellPosition>[
        for (int r = clipped.top; r <= clipped.bottom; r++)
          for (int c = clipped.left; c <= clipped.right; c++) CellPosition(c, r),
      ]);
    },
  );
}

/// Отмечает или снимает отметку со всех клеток одного цвета ([color] — номер в палитре с нуля).
class MarkColor extends _MarkCommand {
  const MarkColor({required super.patterns, required super.progress});

  Future<Result<void>> call({required String projectId, required int color, required bool done}) => run(
    projectId,
    done: done,
    pick: (pattern) {
      final Grid grid = pattern.grid;
      if (color < 0 || color >= pattern.palette.colors.length) {
        return Err<Iterable<CellPosition>>(ValidationFailure('Цвета $color нет в палитре'));
      }
      return Success<Iterable<CellPosition>>(<CellPosition>[
        for (int r = 0; r < grid.height; r++)
          for (int c = 0; c < grid.width; c++)
            if (grid.at(c, r) == color + 1) CellPosition(c, r),
      ]);
    },
  );
}
