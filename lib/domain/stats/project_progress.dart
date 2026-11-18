import 'package:beading/domain/grid/reading_order.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/domain/grid_pattern/cell_progress_store.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/grid_pattern/grid_progress_store.dart';
import 'package:beading/domain/grid_pattern/stitch_counters.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:equatable/equatable.dart';

/// Прогресс проекта на сегодня в клетках (крестиках или бусинах); у бисера ещё и в рядах.
final class ProjectProgress extends Equatable {
  const ProjectProgress({required this.done, required this.total, this.rowsDone, this.rowsTotal});

  final int done;
  final int total;

  /// Только у бисера: сколько рядов плетения отмечено и сколько их всего.
  final int? rowsDone;
  final int? rowsTotal;

  int get remaining => total - done;

  double get fraction => total == 0 ? 0 : (done / total).clamp(0.0, 1.0);

  /// Готовность в целых процентах так же, как на карточке: 100 — только когда всё сделано.
  int get percent {
    if (total > 0 && done >= total) {
      return 100;
    }
    if (done <= 0) {
      return 0;
    }
    return (fraction * 100).floor().clamp(1, 99);
  }

  @override
  List<Object?> get props => <Object?>[done, total, rowsDone, rowsTotal];
}

/// Читает прогресс проекта из хранилищ (без обложки и картинок, в отличие от превью карточки).
class ProjectProgressReader {
  const ProjectProgressReader({
    required GridPatternRepository patterns,
    required GridProgressStore rows,
    required CellProgressStore cells,
  }) : _patterns = patterns,
       _rows = rows,
       _cells = cells;

  final GridPatternRepository _patterns;
  final GridProgressStore _rows;
  final CellProgressStore _cells;

  /// `null`, если считать нечего (схема из книги, инструкция) или хранилище не прочиталось.
  Future<ProjectProgress?> read(Project project) async {
    if (project.contentKind != ContentKind.grid) {
      return null;
    }
    try {
      final GridPattern? pattern = (await _patterns.getByProject(project.id)).valueOrNull;
      if (pattern == null) {
        return null;
      }
      if (project.craft == Craft.crossStitch) {
        final CellProgress cells = (await _cells.load(pattern.id)).valueOrNull ?? const CellProgress.none();
        final ({int total, int done}) count = StitchCounters.overall(pattern.grid, cells);
        return ProjectProgress(done: count.done, total: count.total);
      }
      final GridProgress rows = (await _rows.load(pattern.id)).valueOrNull ?? const GridProgress.empty();
      return _beads(pattern, rows);
    } on Object {
      return null;
    }
  }

  ProjectProgress _beads(GridPattern pattern, GridProgress progress) {
    final ReadingOrder order = ReadingOrder.of(
      pattern.geometry,
      columns: pattern.grid.width,
      rows: pattern.grid.height,
    );
    int total = 0;
    int done = 0;
    int rowsDone = 0;
    for (int index = 0; index < order.rowCount; index++) {
      final bool marked = progress.completedRows.contains(index);
      int beads = 0;
      for (final cell in order.row(index).cells) {
        if (pattern.grid.at(cell.column, cell.row) != 0) {
          beads++;
        }
      }
      total += beads;
      if (marked) {
        done += beads;
        rowsDone++;
      }
    }
    return ProjectProgress(done: done, total: total, rowsDone: rowsDone, rowsTotal: order.rowCount);
  }
}
