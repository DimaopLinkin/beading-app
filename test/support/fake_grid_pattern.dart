import 'dart:async';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/grid_pattern/grid_progress_store.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Палитра из двух цветов: красный и смешанная нить.
PaletteSnapshot samplePalette() => PaletteSnapshot(<PatternColor>[
  PatternColor(
    rgb: const Rgb(200, 10, 20),
    name: 'Красный',
    components: const <CatalogRef>[CatalogRef(brand: 'Miyuki Delica', code: 'DB0010')],
    finish: 'matte',
    symbol: 'A',
  ),
  PatternColor(
    rgb: const Rgb(30, 40, 50),
    name: 'Смесь',
    components: const <CatalogRef>[
      CatalogRef(brand: 'DMC', code: '310'),
      CatalogRef(brand: 'DMC', code: '666'),
    ],
    symbol: 'B',
  ),
]);

/// Схема 4×3 с обоими цветами палитры.
GridPattern sampleGridPattern({String id = 'pat-1', String projectId = 'proj-1'}) => GridPattern(
  id: id,
  projectId: projectId,
  geometry: const PeyoteGeometry(drop: 2),
  metrics: BeadSize.delica11,
  grid: Grid.fromCells(width: 4, height: 3, cells: const <int>[1, 2, 0, 1, 2, 2, 1, 0, 0, 1, 1, 2]),
  palette: samplePalette(),
);

/// Хранилище схем в памяти. [failNextSave] заставляет следующую запись вернуть ошибку.
class FakeGridPatternRepository implements GridPatternRepository {
  final Map<String, GridPattern> byProject = <String, GridPattern>{};
  final StreamController<void> _changes = StreamController<void>.broadcast(sync: true);
  Failure? failNextSave;
  final List<String> deletedProjects = <String>[];

  @override
  Future<Result<GridPattern>> getByProject(String projectId) async {
    final GridPattern? pattern = byProject[projectId];
    return pattern == null ? Err<GridPattern>(NotFoundFailure('нет сетки $projectId')) : Success<GridPattern>(pattern);
  }

  @override
  Future<Result<GridPatternSummary>> summaryByProject(String projectId) async {
    final GridPattern? pattern = byProject[projectId];
    return pattern == null
        ? Err<GridPatternSummary>(NotFoundFailure('нет сетки $projectId'))
        : Success<GridPatternSummary>(
            GridPatternSummary(
              id: pattern.id,
              projectId: projectId,
              width: pattern.grid.width,
              height: pattern.grid.height,
            ),
          );
  }

  @override
  Stream<GridPattern?> watchByProject(String projectId) async* {
    yield byProject[projectId];
    await for (final void _ in _changes.stream) {
      yield byProject[projectId];
    }
  }

  @override
  Future<Result<void>> save(GridPattern pattern) async {
    final Failure? failure = failNextSave;
    if (failure != null) {
      failNextSave = null;
      return Err<void>(failure);
    }
    byProject[pattern.projectId] = pattern;
    _changes.add(null);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> deleteByProject(String projectId) async {
    deletedProjects.add(projectId);
    byProject.remove(projectId);
    _changes.add(null);
    return const Success<void>(null);
  }
}

/// Прогресс в памяти.
class FakeGridProgressStore implements GridProgressStore {
  final Set<int> rows = <int>{};
  int? currentRow;
  int? currentBead;
  final List<String> calls = <String>[];

  @override
  Future<Result<GridProgress>> load(String patternId) async =>
      Success<GridProgress>(GridProgress(completedRows: rows, currentRow: currentRow, currentBead: currentBead));

  @override
  Stream<GridProgress> watch(String patternId) => const Stream<GridProgress>.empty();

  @override
  Future<Result<void>> markRow(String patternId, int row) async {
    calls.add('mark $patternId $row');
    rows.add(row);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> unmarkRow(String patternId, int row) async {
    calls.add('unmark $patternId $row');
    rows.remove(row);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> setCurrent(String patternId, {required int row, int? bead}) async {
    calls.add('current $patternId $row $bead');
    currentRow = row;
    currentBead = bead;
    return const Success<void>(null);
  }
}
