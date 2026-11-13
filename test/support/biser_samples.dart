import 'dart:math';
import 'dart:typed_data';

import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/image_pattern/book_work/page_markup.dart';
import 'package:beading/domain/image_pattern/book_work/page_viewport.dart';
import 'package:beading/domain/image_pattern/book_work/page_work.dart';
import 'package:beading/domain/image_pattern/book_work/pattern_zone.dart';
import 'package:beading/domain/image_pattern/book_work/ruler_state.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/sharing/biser/biser_models.dart';
import 'package:beading/domain/weaving/work_session.dart';

import 'fake_grid_pattern.dart';

/// Подпись PNG и немного байтов: достаточно для проверки «это картинка».
Uint8List fakePng(int seed) =>
    Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, seed, seed + 1, seed + 2]);

/// Случайный, но воспроизводимый набор проектов: сетки разной формы и схемы из книг с прогрессом.
BiserBundle randomBundle(int seed, {int projects = 4}) {
  final Random random = Random(seed);
  final List<BiserProject> items = <BiserProject>[];
  final Map<String, Uint8List> files = <String, Uint8List>{};
  for (int i = 0; i < projects; i++) {
    final String id = 'p$seed-$i';
    final bool grid = random.nextBool();
    final Craft craft = random.nextBool() ? Craft.beading : Craft.crossStitch;
    final Technique technique = craft.techniques[random.nextInt(craft.techniques.length)];
    final Project project = Project(
      id: id,
      name: 'Проект $i «${random.nextInt(1000)}»',
      status: ProjectStatus.values[random.nextInt(ProjectStatus.values.length)],
      craft: craft,
      technique: technique,
      contentKind: grid ? ContentKind.grid : ContentKind.image,
      notes: random.nextBool() ? '' : 'Заметка ${random.nextInt(100)}\nвторая строка',
      coverPath: null,
      lastWorkedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000 + random.nextInt(100000000), isUtc: true),
    );
    if (grid) {
      final int width = 1 + random.nextInt(12);
      final int height = 1 + random.nextInt(12);
      final GridPattern base = sampleGridPattern(id: 'pat-$id', projectId: id);
      final List<int> cells = <int>[for (int c = 0; c < width * height; c++) random.nextInt(base.palette.length + 1)];
      final Set<int> rows = <int>{
        for (int r = 0; r < height; r++)
          if (random.nextBool()) r,
      };
      final int currentRow = random.nextInt(height);
      items.add(
        BiserProject(
          project: project,
          grid: GridPattern(
            id: 'pat-$id',
            projectId: id,
            geometry: random.nextBool()
                ? const GridGeometry.rectangular()
                : GridGeometry.peyote(drop: 1 + random.nextInt(3)),
            metrics: BeadSize.delica11,
            grid: Grid.fromCells(width: width, height: height, cells: cells),
            palette: base.palette,
          ),
          progress: GridProgress(
            completedRows: rows,
            currentRow: random.nextBool() ? currentRow : null,
          ),
          cells: random.nextBool()
              ? CellProgress(width: width).withCells(<CellPosition>[
                  for (int n = 0; n < 1 + random.nextInt(8); n++)
                    CellPosition(random.nextInt(width), random.nextInt(height)),
                ], done: true)
              : null,
          workSessions: sampleWorkSessions(id, i),
        ),
      );
    } else {
      final int pageCount = 1 + random.nextInt(3);
      final List<BiserPage> pages = <BiserPage>[];
      for (int p = 0; p < pageCount; p++) {
        final String pageId = 'pg-$id-$p';
        final String file = 'images/$pageId.png';
        files[file] = fakePng(seed + p);
        pages.add(
          BiserPage(
            id: pageId,
            file: file,
            width: 100 + random.nextInt(900),
            height: 100 + random.nextInt(900),
            work: random.nextBool()
                ? null
                : PageWork(
                    pageId: pageId,
                    ruler: RulerState(
                      top: random.nextDouble() * 50,
                      height: 4 + random.nextDouble() * 20,
                      step: 1 + random.nextDouble() * 10,
                      highlight: RulerHighlight.values[random.nextInt(RulerHighlight.values.length)],
                      row: 1 + random.nextInt(30),
                      direction: RowDirection.values[random.nextInt(RowDirection.values.length)],
                      // Зона и число рядов — по зерну, без генератора: остальные значения наборов не сдвигаются.
                      zone: (seed + p).isEven
                          ? PatternZone(top: 2.5 + p, bottom: 80.5 + seed, left: 1.25, right: 90 + p.toDouble())
                          : null,
                      rowCount: (seed + p) % 3 == 0 ? 10 + seed : null,
                    ),
                    viewport: PageViewport(
                      scale: 1 + random.nextDouble() * 3,
                      dx: random.nextDouble() * -20,
                      dy: random.nextDouble() * -20,
                    ),
                    // Пометки маркером (T45) — по зерну, значения точно представимы во float32.
                    markup: (seed + p) % 3 == 1
                        ? PageMarkup(<MarkerStroke>[
                            MarkerStroke(rgb: 0xFFE45C, width: 0.0625, points: const <double>[0.25, 0.5, 0.5, 0.75]),
                            MarkerStroke(rgb: 0x7CC8FF, width: 0.125, points: const <double>[0.125, 0.125]),
                          ])
                        : const PageMarkup.empty(),
                  ),
          ),
        );
      }
      items.add(
        BiserProject(
          project: project,
          book: BiserBook(patternId: 'book-$id', pages: pages, currentPageId: random.nextBool() ? pages.last.id : null),
          coverPageId: random.nextBool() ? pages.first.id : null,
          workSessions: sampleWorkSessions(id, i),
        ),
      );
    }
  }
  return BiserBundle(
    kind: BiserKind.backup,
    exportedAt: DateTime.utc(2026, 11, 10, 9),
    appVersion: '0.1.0',
    projects: items,
    files: files,
  );
}

/// Две сессии работы: законченная на 20 минут и вторая, которую ни разу не обновили. Без генератора: наборы не сдвигаются.
List<WorkSession> sampleWorkSessions(String projectId, int index) {
  final DateTime start = DateTime.utc(2026, 11, 1, 10 + index);
  return <WorkSession>[
    WorkSession(
      id: 'imported-0',
      projectId: projectId,
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 20)),
    ),
    WorkSession(id: 'imported-1', projectId: projectId, startedAt: start.add(const Duration(days: 1))),
  ];
}
