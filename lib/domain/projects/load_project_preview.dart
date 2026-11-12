import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/reading_order.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/domain/grid_pattern/cell_progress_store.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/grid_pattern/grid_progress_store.dart';
import 'package:beading/domain/grid_pattern/stitch_counters.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:equatable/equatable.dart';

/// Что показать на карточке проекта в списке: картинка и процент готовности.
final class ProjectPreview extends Equatable {
  const ProjectPreview({this.progress, this.pattern, this.cover});

  /// Доля готового, 0..1; `null`, когда считать нечего (схема из книги: у неё нет клеток).
  final double? progress;

  /// Сетка схемы для превью; `null` у проектов не из сетки.
  final GridPattern? pattern;

  /// Первая страница схемы из книги (PNG); `null`, если обложки нет или файл не читается.
  final Uint8List? cover;

  /// Готовность в целых процентах; доля меньше процента, но не ноль, показывается как 1 %, а 99,6 % — как 99 %:
  /// 100 % говорят только когда всё сделано.
  int? get percent {
    final double? value = progress;
    if (value == null) {
      return null;
    }
    if (value >= 1) {
      return 100;
    }
    if (value <= 0) {
      return 0;
    }
    return (value * 100).floor().clamp(1, 99);
  }

  @override
  List<Object?> get props => <Object?>[progress, pattern, cover];
}

/// Собирает [ProjectPreview] из хранилищ. Любой сбой чтения даёт пустое превью: карточка тогда рисует значок ремесла.
class LoadProjectPreview {
  const LoadProjectPreview({
    required GridPatternRepository patterns,
    required GridProgressStore rows,
    required CellProgressStore cells,
    required FileStore files,
  }) : _patterns = patterns,
       _rows = rows,
       _cells = cells,
       _files = files;

  final GridPatternRepository _patterns;
  final GridProgressStore _rows;
  final CellProgressStore _cells;
  final FileStore _files;

  Future<ProjectPreview> call(Project project) async {
    try {
      return switch (project.contentKind) {
        ContentKind.grid => await _grid(project),
        ContentKind.image => await _image(project),
        ContentKind.steps => const ProjectPreview(),
      };
    } on Object {
      return const ProjectPreview();
    }
  }

  Future<ProjectPreview> _grid(Project project) async {
    final Result<GridPattern> found = await _patterns.getByProject(project.id);
    final GridPattern? pattern = found.valueOrNull;
    if (pattern == null) {
      return const ProjectPreview();
    }
    if (project.craft == Craft.crossStitch) {
      final CellProgress cells = (await _cells.load(pattern.id)).valueOrNull ?? const CellProgress.none();
      final ({int total, int done}) count = StitchCounters.overall(pattern.grid, cells);
      return ProjectPreview(pattern: pattern, progress: count.total == 0 ? 0 : count.done / count.total);
    }
    final GridProgress rows = (await _rows.load(pattern.id)).valueOrNull ?? const GridProgress.empty();
    final int rowCount = ReadingOrder.of(
      pattern.geometry,
      columns: pattern.grid.width,
      rows: pattern.grid.height,
    ).rowCount;
    return ProjectPreview(
      pattern: pattern,
      progress: rowCount == 0 ? 0 : (rows.completedRows.length / rowCount).clamp(0.0, 1.0),
    );
  }

  Future<ProjectPreview> _image(Project project) async {
    final String? path = project.coverPath;
    if (path == null) {
      return const ProjectPreview();
    }
    return ProjectPreview(cover: (await _files.read(path)).valueOrNull);
  }
}
