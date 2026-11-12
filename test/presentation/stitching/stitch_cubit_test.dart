import 'package:beading/core/failure.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/use_cases/cell_progress_commands.dart';
import 'package:beading/domain/image_pattern/book_work/record_book_progress.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/change_project_status.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/weaving/work_session_tracker.dart';
import 'package:beading/presentation/stitching/stitch_cubit.dart';
import 'package:beading/presentation/stitching/stitch_state.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/fake_work_sessions.dart';

/// 4 × 3, одна пустая клетка (2, 0): первого цвета 7 клеток, второго 4.
GridPattern _pattern(String projectId) => GridPattern(
  id: 'pat-1',
  projectId: projectId,
  geometry: const GridGeometry.rectangular(),
  metrics: BeadSize.delica11,
  grid: Grid.fromCells(width: 4, height: 3, cells: const <int>[1, 2, 0, 1, 2, 2, 1, 1, 1, 1, 1, 2]),
  palette: samplePalette(),
);

void main() {
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;
  late FakeCellProgressStore cells;
  late FakeGridProgressStore rows;
  late FakeSettingsRepository settings;
  late FakeWorkSessionRepository sessions;
  late FakeClock clock;
  late BroadcastAppEvents events;
  late List<AppEvent> published;
  late String projectId;

  setUp(() async {
    projects = FakeProjectRepository();
    patterns = FakeGridPatternRepository();
    cells = FakeCellProgressStore();
    rows = FakeGridProgressStore();
    settings = FakeSettingsRepository();
    sessions = FakeWorkSessionRepository();
    clock = FakeClock(DateTime.utc(2026, 11, 11, 9));
    events = BroadcastAppEvents();
    published = <AppEvent>[];
    events.stream.listen(published.add);
    projectId = (await CreateProject(repository: projects, ids: FakeIdGenerator(), clock: clock)(
      name: 'Котик',
    )).valueOrNull!.id;
    patterns.byProject[projectId] = _pattern(projectId);
  });

  tearDown(() => events.dispose());

  StitchCubit create() {
    final ChangeProjectStatus changeStatus = ChangeProjectStatus(repository: projects, events: events);
    return StitchCubit(
      projectId: projectId,
      projects: projects,
      patterns: patterns,
      cellProgress: cells,
      progress: rows,
      markCells: MarkCells(patterns: patterns, progress: cells),
      markRect: MarkRect(patterns: patterns, progress: cells),
      markColor: MarkColor(patterns: patterns, progress: cells),
      settings: settings,
      recordProgress: RecordBookProgress(
        projects: projects,
        changeStatus: changeStatus,
        touch: TouchProject(repository: projects, clock: clock),
      ),
      changeStatus: changeStatus,
      tracker: WorkSessionTracker(sessions: sessions, clock: clock),
      events: events,
    );
  }

  Future<StitchCubit> loaded() async {
    final StitchCubit cubit = create();
    await cubit.load();
    return cubit;
  }

  test('load: счётчики, блоки, ничего не сделано', () async {
    final StitchCubit cubit = await loaded();
    final StitchState s = cubit.state;
    expect(s.status, StitchStatus.ready);
    expect(s.projectName, 'Котик');
    expect(s.total, 11);
    expect(s.done, 0);
    expect(s.remaining, 11);
    expect(s.byColor.map((c) => c.total), <int>[7, 4]);
    expect(s.blocks, hasLength(1));
    expect(s.fraction, 0);
    await cubit.close();
  });

  test('схемы нет — экран ошибки', () async {
    patterns.byProject.clear();
    final StitchCubit cubit = await loaded();
    expect(cubit.state.status, StitchStatus.failed);
    await cubit.close();
  });

  test('касание отмечает клетку и пишет на диск; повторное снимает; пустая клетка не отмечается', () async {
    final StitchCubit cubit = await loaded();
    cubit.tapCell(const CellPosition(0, 0));
    expect(cubit.state.done, 1);
    expect(cubit.state.progress.isDone(0, 0), isTrue);
    expect(cubit.state.marks, 1);
    cubit.tapCell(const CellPosition(2, 0));
    expect(cubit.state.done, 1, reason: 'на пустой клетке отметки нет');
    await cubit.close();
    expect(cells.blocksByPattern['pat-1'], isNotEmpty);

    final StitchCubit again = await loaded();
    expect(again.state.progress.isDone(0, 0), isTrue, reason: 'прогресс переживает перезапуск экрана');
    again.tapCell(const CellPosition(0, 0));
    expect(again.state.done, 0);
    await again.close();
    expect(cells.blocksByPattern['pat-1'], isEmpty);
  });

  test('первая отметка переводит проект «идея» в «в работе»', () async {
    final StitchCubit cubit = await loaded();
    cubit.tapCell(const CellPosition(0, 0));
    await cubit.close();
    expect((await projects.get(projectId)).valueOrNull!.status, ProjectStatus.inProgress);
  });

  test('мазок: одна запись на весь мазок; мазок по сделанным клеткам снимает отметки', () async {
    final StitchCubit cubit = await loaded();
    cubit
      ..strokeStart()
      ..strokeCell(const CellPosition(0, 0))
      ..strokeCell(const CellPosition(1, 0))
      ..strokeCell(const CellPosition(1, 0))
      ..strokeCell(const CellPosition(2, 0))
      ..strokeCell(const CellPosition(3, 0));
    expect(cubit.state.progress.count, 3, reason: 'видно сразу, пустая клетка пропущена');
    cubit.strokeEnd();
    expect(cubit.state.done, 3);
    await pumpEventQueue();
    expect(cells.calls, hasLength(1));
    cubit
      ..strokeStart()
      ..strokeCell(const CellPosition(1, 0))
      ..strokeCell(const CellPosition(0, 0))
      ..strokeEnd();
    expect(cubit.state.done, 1);
    await cubit.close();
  });

  test('мазок без клеток и strokeEnd без начала ничего не пишут', () async {
    final StitchCubit cubit = await loaded();
    cubit
      ..strokeEnd()
      ..strokeStart()
      ..strokeCell(const CellPosition(2, 0))
      ..strokeEnd();
    await cubit.close();
    expect(cells.calls, isEmpty);
  });

  test('область: отмечает, а если всё в ней сделано — снимает; рамка видна, пока тянут', () async {
    final StitchCubit cubit = await loaded();
    cubit.areaDrag(const CellPosition(0, 0), const CellPosition(1, 1));
    expect(cubit.state.areaPreview, isNotNull);
    cubit.areaEnd();
    expect(cubit.state.areaPreview, isNull);
    expect(cubit.state.done, 4);
    cubit
      ..areaDrag(const CellPosition(0, 0), const CellPosition(1, 1))
      ..areaEnd();
    expect(cubit.state.done, 0);
    cubit
      ..areaDrag(const CellPosition(2, 0), const CellPosition(2, 0))
      ..areaEnd();
    expect(cubit.state.done, 0, reason: 'в области одна пустая клетка');
    cubit.areaEnd();
    await cubit.close();
  });

  group('откат', () {
    test('касание откатывается без тоста; кнопка гаснет, когда откатывать нечего', () async {
      final StitchCubit cubit = await loaded();
      expect(cubit.state.canUndo, isFalse);
      cubit.tapCell(const CellPosition(0, 0));
      expect(cubit.state.canUndo, isTrue);
      expect(cubit.state.undoNotice, isNull, reason: 'тост только после действия на несколько клеток');
      cubit.undo();
      expect(cubit.state.done, 0);
      expect(cubit.state.canUndo, isFalse);
      cubit.undo();
      expect(cubit.state.done, 0);
      await cubit.close();
      expect(cells.blocksByPattern['pat-1'], isEmpty, reason: 'откат записан на диск');
    });

    test('откат мазка не снимает клетки, которые были сделаны до него', () async {
      final StitchCubit cubit = await loaded();
      cubit.tapCell(const CellPosition(0, 0));
      cubit
        ..strokeStart()
        ..strokeCell(const CellPosition(1, 0))
        ..strokeCell(const CellPosition(0, 0))
        ..strokeCell(const CellPosition(3, 0))
        ..strokeEnd();
      expect(cubit.state.done, 3);
      cubit.undo();
      expect(cubit.state.done, 1);
      expect(cubit.state.progress.isDone(0, 0), isTrue);
      await cubit.close();
    });

    test('мазок: тост «отмечено N», откат возвращает как было', () async {
      final StitchCubit cubit = await loaded();
      cubit
        ..strokeStart()
        ..strokeCell(const CellPosition(0, 0))
        ..strokeCell(const CellPosition(1, 0))
        ..strokeCell(const CellPosition(3, 0))
        ..strokeEnd();
      expect(cubit.state.done, 3);
      expect(cubit.state.undoNotice, (count: 3, done: true));
      cubit.undo();
      expect(cubit.state.done, 0);
      expect(cubit.state.undoNotice, isNull);
      await cubit.close();
    });

    test('область и цвет целиком откатываются по одному действию, в обратном порядке', () async {
      final StitchCubit cubit = await loaded();
      cubit.markColor(1);
      expect(cubit.state.done, 4);
      cubit
        ..setTool(StitchTool.area)
        ..areaDrag(const CellPosition(0, 0), const CellPosition(3, 0))
        ..areaEnd();
      final int afterArea = cubit.state.done;
      expect(afterArea, greaterThan(4));
      cubit.undo();
      expect(cubit.state.done, 4);
      cubit.undo();
      expect(cubit.state.done, 0);
      await cubit.close();
    });

    test('снятие отметок откатывается обратно отметкой; тост «снято»', () async {
      final StitchCubit cubit = await loaded();
      cubit.markColor(1);
      cubit.markColor(1);
      expect(cubit.state.done, 0);
      expect(cubit.state.undoNotice, (count: 4, done: false));
      cubit.undo();
      expect(cubit.state.done, 4);
      await cubit.close();
    });

    test('тост сам пропадает через пять секунд, откат остаётся; dismissUndoNotice скрывает тост', () {
      fakeAsync((async) {
        final StitchCubit cubit = create();
        cubit.load();
        async.flushMicrotasks();
        cubit.markColor(1);
        expect(cubit.state.undoNotice, isNotNull);
        async.elapse(const Duration(seconds: 6));
        expect(cubit.state.undoNotice, isNull);
        expect(cubit.state.canUndo, isTrue);
        cubit.markColor(1);
        expect(cubit.state.undoNotice, isNotNull);
        cubit.dismissUndoNotice();
        expect(cubit.state.undoNotice, isNull);
        cubit.close();
        async.flushMicrotasks();
      });
    });

    test('история ограничена тридцатью действиями', () async {
      final StitchCubit cubit = await loaded();
      for (int i = 0; i < 32; i++) {
        cubit.tapCell(CellPosition(i.isEven ? 0 : 1, 0));
      }
      int undone = 0;
      while (cubit.state.canUndo) {
        cubit.undo();
        undone++;
      }
      expect(undone, 30);
      await cubit.close();
    });
  });

  test('по цвету: отмечает все клетки цвета, повторно снимает; подсветка переключается', () async {
    final StitchCubit cubit = await loaded();
    cubit.markColor(1);
    expect(cubit.state.byColor[1].done, 4);
    expect(cubit.state.done, 4);
    cubit.markColor(1);
    expect(cubit.state.done, 0);
    cubit.markColor(9);
    cubit.highlight(2);
    expect(cubit.state.highlight, 2);
    cubit.highlight(2);
    expect(cubit.state.highlight, isNull);
    await cubit.close();
  });

  test('события: закрыт цвет и закрыт блок; offerFinish, когда сделано всё, и «готово» проекта', () async {
    final StitchCubit cubit = await loaded();
    cubit.markColor(0);
    expect(published.whereType<StitchColorCompleted>(), hasLength(1));
    expect(cubit.state.offerFinish, isFalse);
    cubit.markColor(1);
    expect(published.whereType<StitchColorCompleted>(), hasLength(2));
    expect(published.whereType<StitchBlockCompleted>().single.total, 1);
    expect(cubit.state.allDone, isTrue);
    expect(cubit.state.offerFinish, isTrue);
    await cubit.finishProject();
    expect(cubit.state.projectDone, isTrue);
    expect(cubit.state.offerFinish, isFalse);
    await cubit.close();
    expect((await projects.get(projectId)).valueOrNull!.status, ProjectStatus.done);
  });

  test('снятие отметки событий не шлёт; dismissFinish скрывает предложение', () async {
    final StitchCubit cubit = await loaded();
    cubit
      ..markColor(0)
      ..markColor(1);
    cubit.dismissFinish();
    expect(cubit.state.offerFinish, isFalse);
    published.clear();
    cubit.markColor(0);
    expect(published.whereType<StitchColorCompleted>(), isEmpty);
    await cubit.close();
  });

  test('парковка запоминается и восстанавливается', () async {
    final StitchCubit cubit = await loaded();
    cubit.park(const CellPosition(3, 2));
    expect(cubit.state.parked, const CellPosition(3, 2));
    cubit.park(const CellPosition(9, 9));
    expect(cubit.state.parked, const CellPosition(3, 2));
    await cubit.close();
    expect(rows.currentRow, 2);
    expect(rows.currentBead, 3);
    final StitchCubit again = await loaded();
    expect(again.state.parked, const CellPosition(3, 2));
    await again.close();
  });

  test('инструмент, символы и блоки переключаются; значения символов берутся из настроек', () async {
    await settings.write<bool>(SettingKeys.symbolMode, true);
    final StitchCubit cubit = await loaded();
    expect(cubit.state.showSymbols, isTrue);
    cubit
      ..toggleSymbols()
      ..toggleBlocks()
      ..setTool(StitchTool.area);
    expect(cubit.state.showSymbols, isFalse);
    expect(cubit.state.showBlocks, isFalse);
    expect(cubit.state.tool, StitchTool.area);
    await cubit.close();
  });

  test('сбой записи показывается и проходит после удачной записи', () async {
    final StitchCubit cubit = await loaded();
    cells.failNextWrite = const StorageFailure('диск');
    cubit.tapCell(const CellPosition(0, 0));
    await pumpEventQueue();
    expect(cubit.state.saveFailed, isTrue);
    cubit.tapCell(const CellPosition(1, 0));
    await pumpEventQueue();
    expect(cubit.state.saveFailed, isFalse);
    await cubit.close();
  });

  test('время работы: сессия идёт, пока экран открыт', () async {
    final StitchCubit cubit = await loaded();
    await pumpEventQueue();
    expect(sessions.sessions, isNotEmpty);
    await cubit.pause();
    await cubit.resume();
    await cubit.close();
  });
}
