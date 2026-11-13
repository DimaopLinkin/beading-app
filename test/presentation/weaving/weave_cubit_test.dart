import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid/word_chart.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/image_pattern/book_work/record_book_progress.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/change_project_status.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/weaving/rows_counter.dart';
import 'package:beading/domain/weaving/work_session_tracker.dart';
import 'package:beading/presentation/weaving/weave_cubit.dart';
import 'package:beading/presentation/weaving/weave_state.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/fake_work_sessions.dart';

/// 4 × 3: в первом ряду пустая ячейка (бусин 3), в остальных по 4.
GridPattern _pattern(String projectId, {GridGeometry geometry = const GridGeometry.rectangular()}) => GridPattern(
  id: 'pat-1',
  projectId: projectId,
  geometry: geometry,
  metrics: BeadSize.delica11,
  grid: Grid.fromCells(width: 4, height: 3, cells: const <int>[1, 2, 0, 1, 2, 2, 1, 1, 1, 1, 1, 2]),
  palette: samplePalette(),
);

void main() {
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;
  late FakeGridProgressStore progress;
  late FakeSettingsRepository settings;
  late FakeWorkSessionRepository sessions;
  late FakeClock clock;
  late BroadcastAppEvents events;
  late List<AppEvent> published;
  late String projectId;

  setUp(() async {
    projects = FakeProjectRepository();
    patterns = FakeGridPatternRepository();
    progress = FakeGridProgressStore();
    settings = FakeSettingsRepository();
    sessions = FakeWorkSessionRepository();
    clock = FakeClock(DateTime.utc(2026, 11, 10, 9));
    events = BroadcastAppEvents();
    published = <AppEvent>[];
    events.stream.listen(published.add);
    projectId = (await CreateProject(repository: projects, ids: FakeIdGenerator(), clock: clock)(
      name: 'Браслет',
    )).valueOrNull!.id;
    patterns.byProject[projectId] = _pattern(projectId);
  });

  tearDown(() => events.dispose());

  WeaveCubit create({Duration toast = const Duration(seconds: 4)}) {
    final ChangeProjectStatus changeStatus = ChangeProjectStatus(repository: projects, events: events);
    return WeaveCubit(
      projectId: projectId,
      projects: projects,
      patterns: patterns,
      progress: progress,
      settings: settings,
      recordProgress: RecordBookProgress(
        projects: projects,
        changeStatus: changeStatus,
        touch: TouchProject(repository: projects, clock: clock),
      ),
      changeStatus: changeStatus,
      rowsCounter: RowsCounter(settings: settings, events: events),
      tracker: WorkSessionTracker(sessions: sessions, clock: clock),
      toastDuration: toast,
    );
  }

  Future<WeaveCubit> loaded() async {
    final WeaveCubit cubit = create();
    await cubit.load();
    return cubit;
  }

  /// Дожидается записей, поставленных в очередь.
  Future<void> settle(WeaveCubit cubit) => cubit.close();

  test('load: первый ряд, word chart, статус «готово к работе»', () async {
    final WeaveCubit cubit = await loaded();
    final WeaveState s = cubit.state;
    expect(s.status, WeaveStatus.ready);
    expect(s.projectName, 'Браслет');
    expect(s.row, 0);
    expect(s.rowCount, 3);
    expect(s.rowNumber, 1);
    expect(s.beadCount, 3);
    expect(s.runs, const <WordRun>[WordRun(1, 1), WordRun(2, 1), WordRun(1, 1)]);
    expect(s.direction.name, 'right');
    expect(s.progress, 0);
    expect(s.isReady, isTrue);
    expect(s.canGoBack, isFalse);
    expect(s.pendingBeads, isEmpty); // «по ряду»
    await settle(cubit);
  });

  test('load: нет проекта или схемы — failed', () async {
    patterns.byProject.clear();
    final WeaveCubit cubit = create();
    await cubit.load();
    expect(cubit.state.status, WeaveStatus.failed);
    await cubit.close();
  });

  test('load: сбой чтения прогресса — failed', () async {
    final WeaveCubit cubit = WeaveCubit(
      projectId: projectId,
      projects: projects,
      patterns: patterns,
      progress: _FailingProgress(),
      settings: settings,
      recordProgress: RecordBookProgress(
        projects: projects,
        changeStatus: ChangeProjectStatus(repository: projects, events: events),
        touch: TouchProject(repository: projects, clock: clock),
      ),
      changeStatus: ChangeProjectStatus(repository: projects, events: events),
      rowsCounter: RowsCounter(settings: settings, events: events),
      tracker: WorkSessionTracker(sessions: sessions, clock: clock),
    );
    await cubit.load();
    expect(cubit.state.status, WeaveStatus.failed);
    await cubit.close();
  });

  test('load: восстановление после перезапуска — ряд, отметки и бусина', () async {
    progress
      ..rows.addAll(<int>{0})
      ..currentRow = 1
      ..currentBead = 2;
    await settings.write<bool>(SettingKeys.weaveByBead, true);
    final WeaveCubit cubit = await loaded();
    expect(cubit.state.row, 1);
    expect(cubit.state.laid, 2);
    expect(cubit.state.mode, WeaveMode.byBead);
    expect(cubit.state.completedRows, <int>{0});
    expect(cubit.state.pendingBeads, hasLength(2));
    expect(cubit.state.nextBead, isNotNull);
    await settle(cubit);
  });

  test('load: без сохранённого текущего ряда — первый не отмеченный; всё отмечено — последний', () async {
    progress.rows.addAll(<int>{0, 1});
    final WeaveCubit a = await loaded();
    expect(a.state.row, 2);
    await a.close();

    progress.rows.addAll(<int>{0, 1, 2});
    final WeaveCubit b = await loaded();
    expect(b.state.row, 2);
    expect(b.state.allDone, isTrue);
    await b.close();
  });

  test('load: мусор в сохранённом прогрессе не ломает экран', () async {
    progress
      ..rows.addAll(<int>{1, 99})
      ..currentRow = 50
      ..currentBead = 77;
    await settings.write<bool>(SettingKeys.weaveByBead, true);
    final WeaveCubit cubit = await loaded();
    expect(cubit.state.row, 2);
    expect(cubit.state.completedRows, <int>{1});
    expect(cubit.state.laid, lessThan(cubit.state.beadCount));
    await settle(cubit);
  });

  group('по ряду', () {
    test('«ряд готов» отмечает ряд, идёт к следующему, пишет прогресс, шлёт RowsCompleted', () async {
      final WeaveCubit cubit = await loaded();
      cubit.completeRow();
      expect(cubit.state.row, 1);
      expect(cubit.state.completedRows, <int>{0});
      expect(cubit.state.toastRow, 0);
      expect(cubit.state.completions, 1);
      expect(cubit.state.progress, closeTo(1 / 3, 1e-9));
      await settle(cubit);
      expect(progress.rows, <int>{0});
      expect(progress.currentRow, 1);
      expect(progress.currentBead, isNull);
      expect(published, <Matcher>[isA<RowsCompleted>().having((e) => e.total, 'total', 1)]);
      expect(projects.projects[projectId]!.status, ProjectStatus.inProgress);
    });

    test('stepForward в режиме «по ряду» завершает ряд', () async {
      final WeaveCubit cubit = await loaded();
      cubit.stepForward();
      expect(cubit.state.row, 1);
      await settle(cubit);
    });

    test('nextBead в режиме «по ряду» ничего не делает', () async {
      final WeaveCubit cubit = await loaded();
      cubit.nextBead();
      expect(cubit.state.laid, 0);
      expect(cubit.state.row, 0);
      await settle(cubit);
    });

    test(
      'последний ряд: ряд остаётся, всё отмечено, предложение «готово»; повторная отметка ничего не меняет',
      () async {
        final WeaveCubit cubit = await loaded();
        cubit
          ..completeRow()
          ..completeRow()
          ..completeRow();
        expect(cubit.state.row, 2);
        expect(cubit.state.allDone, isTrue);
        expect(cubit.state.offerFinish, isTrue);
        expect(cubit.state.progress, 1);
        final int completions = cubit.state.completions;
        cubit.completeRow();
        expect(cubit.state.completions, completions);
        cubit.stepForward();
        expect(cubit.state.completions, completions);
        await settle(cubit);
        expect(progress.rows, <int>{0, 1, 2});
      },
    );

    test('finishProject: статус «готово», проект завершён, ProjectCompleted', () async {
      final WeaveCubit cubit = await loaded();
      cubit
        ..completeRow()
        ..completeRow()
        ..completeRow();
      await cubit.finishProject();
      expect(cubit.state.offerFinish, isFalse);
      expect(cubit.state.projectDone, isTrue);
      expect(projects.projects[projectId]!.status, ProjectStatus.done);
      expect(published.whereType<ProjectCompleted>(), hasLength(1));
      await settle(cubit);
    });

    test('finishProject: сбой записи проекта — не «готово»', () async {
      final WeaveCubit cubit = await loaded();
      projects.failNextWrite = const StorageFailure('boom');
      await cubit.finishProject();
      expect(cubit.state.projectDone, isFalse);
      await settle(cubit);
    });

    test('проект уже «готов»: предложения нет', () async {
      projects.projects[projectId] = projects.projects[projectId]!.copyWith(status: ProjectStatus.done);
      final WeaveCubit cubit = await loaded();
      expect(cubit.state.projectDone, isTrue);
      cubit
        ..completeRow()
        ..completeRow()
        ..completeRow();
      expect(cubit.state.offerFinish, isFalse);
      await settle(cubit);
    });

    test('dismissFinish прячет предложение', () async {
      final WeaveCubit cubit = await loaded();
      cubit
        ..completeRow()
        ..completeRow()
        ..completeRow()
        ..dismissFinish();
      expect(cubit.state.offerFinish, isFalse);
      cubit.dismissFinish(); // ещё раз безвредно
      await settle(cubit);
    });

    test('назад: снимает отметку прошлого ряда и уменьшает счётчик; на первом ряду назад нельзя', () async {
      final WeaveCubit cubit = await loaded();
      cubit
        ..back()
        ..completeRow()
        ..undoCompletion();
      expect(cubit.state.row, 0);
      expect(cubit.state.completedRows, isEmpty);
      expect(cubit.state.toastRow, isNull);
      expect(cubit.state.canGoBack, isFalse);
      await settle(cubit);
      expect(progress.rows, isEmpty);
      expect(settings.values[SettingKeys.rowsCompleted.name], 0);
    });

    test('назад с последнего отмеченного ряда: ряд открывается заново, предложение «готово» пропадает', () async {
      final WeaveCubit cubit = await loaded();
      cubit
        ..completeRow()
        ..completeRow()
        ..completeRow();
      expect(cubit.state.canGoBack, isTrue);
      cubit.back();
      expect(cubit.state.row, 2);
      expect(cubit.state.completedRows, <int>{0, 1});
      expect(cubit.state.offerFinish, isFalse);
      await settle(cubit);
      expect(progress.rows, <int>{0, 1});
    });

    test('тост исчезает сам, и по dismissToast', () {
      fakeAsync((async) {
        final WeaveCubit cubit = create();
        cubit.load();
        async.flushMicrotasks();
        cubit.completeRow();
        async.flushMicrotasks();
        expect(cubit.state.toastRow, 0);
        async.elapse(const Duration(seconds: 5));
        expect(cubit.state.toastRow, isNull);
        cubit
          ..completeRow()
          ..dismissToast();
        expect(cubit.state.toastRow, isNull);
        cubit.dismissToast();
        cubit.close();
        async.flushMicrotasks();
      });
    });
  });

  group('по бусине', () {
    Future<WeaveCubit> byBead() async {
      final WeaveCubit cubit = await loaded();
      cubit.setMode(WeaveMode.byBead);
      return cubit;
    }

    test('режим запоминается; тот же режим ничего не меняет', () async {
      final WeaveCubit cubit = await byBead();
      expect(cubit.state.mode, WeaveMode.byBead);
      cubit.setMode(WeaveMode.byBead);
      await settle(cubit);
      expect(settings.saveCount, 1);
      expect(settings.values[SettingKeys.weaveByBead.name], true);
    });

    test('бусины выкладываются по одной, текущая и невыложенные видны, прогресс пишется', () async {
      final WeaveCubit cubit = await byBead();
      expect(cubit.state.pendingBeads, hasLength(3));
      cubit.nextBead();
      expect(cubit.state.laid, 1);
      expect(cubit.state.pendingBeads, hasLength(2));
      expect(cubit.state.nextBead, cubit.state.beadCells[1]);
      await settle(cubit);
      expect(progress.currentRow, 0);
      expect(progress.currentBead, 1);
      expect(projects.projects[projectId]!.status, ProjectStatus.inProgress);
    });

    test('бусины пропускают пустые ячейки', () async {
      final WeaveCubit cubit = await byBead();
      // В ряду [1, 2, 0, 1] бусин три; пустая ячейка не бусина.
      expect(cubit.state.cells, hasLength(4));
      expect(cubit.state.beadCells, hasLength(3));
      await settle(cubit);
    });

    test('последняя бусина завершает ряд', () async {
      final WeaveCubit cubit = await byBead();
      cubit
        ..nextBead()
        ..nextBead()
        ..nextBead();
      expect(cubit.state.row, 1);
      expect(cubit.state.laid, 0);
      expect(cubit.state.completedRows, <int>{0});
      await settle(cubit);
      expect(progress.currentRow, 1);
      expect(progress.currentBead, isNull);
    });

    test('«ряд готов» в режиме «по бусине» завершает ряд сразу', () async {
      final WeaveCubit cubit = await byBead();
      cubit
        ..nextBead()
        ..completeRow();
      expect(cubit.state.row, 1);
      expect(cubit.state.laid, 0);
      await settle(cubit);
    });

    test('назад: сначала бусины, затем прошлый ряд на последней бусине', () async {
      final WeaveCubit cubit = await byBead();
      cubit
        ..nextBead()
        ..back();
      expect(cubit.state.laid, 0);
      cubit
        ..completeRow()
        ..back();
      expect(cubit.state.row, 0);
      expect(cubit.state.laid, 2); // выложены все, кроме последней
      expect(cubit.state.completedRows, isEmpty);
      await settle(cubit);
      expect(progress.currentBead, 2);
    });

    test('переключение на «по ряду» сбрасывает выложенные бусины и убирает невыложенные', () async {
      final WeaveCubit cubit = await byBead();
      cubit
        ..nextBead()
        ..setMode(WeaveMode.byRow);
      expect(cubit.state.laid, 0);
      expect(cubit.state.pendingBeads, isEmpty);
      expect(cubit.state.nextBead, isNull);
      await settle(cubit);
      expect(progress.currentBead, isNull);
      expect(settings.values[SettingKeys.weaveByBead.name], false);
    });

    test('схема готова: бусин для выкладывания нет', () async {
      final WeaveCubit cubit = await byBead();
      cubit
        ..completeRow()
        ..completeRow()
        ..completeRow();
      expect(cubit.state.allDone, isTrue);
      expect(cubit.state.pendingBeads, isEmpty);
      cubit.nextBead();
      expect(cubit.state.completions, 3);
      await settle(cubit);
    });

    test('ряд без бусин завершается первым же шагом', () async {
      patterns.byProject[projectId] = GridPattern(
        id: 'pat-1',
        projectId: projectId,
        geometry: const GridGeometry.rectangular(),
        metrics: BeadSize.delica11,
        grid: Grid.fromCells(width: 2, height: 2, cells: const <int>[0, 0, 1, 1]),
        palette: samplePalette(),
      );
      final WeaveCubit cubit = await byBead();
      expect(cubit.state.beadCount, 0);
      cubit.nextBead();
      expect(cubit.state.row, 1);
      await settle(cubit);
    });
  });

  group('порядок плетения', () {
    test('пейот: ряд плетения — столбец, рядов на один меньше столбцов, номера прогресса — ряды плетения', () async {
      patterns.byProject[projectId] = _pattern(projectId, geometry: const GridGeometry.peyote());
      final WeaveCubit cubit = await loaded();
      expect(cubit.state.rowCount, 3);
      cubit
        ..completeRow()
        ..completeRow()
        ..completeRow();
      expect(cubit.state.allDone, isTrue);
      await settle(cubit);
      expect(progress.rows, <int>{0, 1, 2});
    });
  });

  group('сбои и служебное', () {
    test('toggleSymbols переключает показ символов', () async {
      final WeaveCubit cubit = await loaded();
      expect(cubit.state.showSymbols, isFalse);
      cubit.toggleSymbols();
      expect(cubit.state.showSymbols, isTrue);
      await settle(cubit);
    });

    test('символы включены в настройках — экран стартует с ними', () async {
      await settings.write<bool>(SettingKeys.symbolMode, true);
      final WeaveCubit cubit = await loaded();
      expect(cubit.state.showSymbols, isTrue);
      await settle(cubit);
    });

    test('сбой записи счётчика рядов не мешает отметке ряда', () async {
      final WeaveCubit cubit = await loaded();
      settings.failWrites = true;
      cubit.completeRow(); // счётчик рядов не записался, но отметка записана
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      cubit.toggleSymbols();
      await settle(cubit);
      expect(progress.rows, <int>{0});
    });

    test('исключение при записи не ломает очередь записей', () async {
      final WeaveCubit cubit = await loaded();
      final _ThrowingProgress throwing = _ThrowingProgress();
      final WeaveCubit broken = WeaveCubit(
        projectId: projectId,
        projects: projects,
        patterns: patterns,
        progress: throwing,
        settings: settings,
        recordProgress: RecordBookProgress(
          projects: projects,
          changeStatus: ChangeProjectStatus(repository: projects, events: events),
          touch: TouchProject(repository: projects, clock: clock),
        ),
        changeStatus: ChangeProjectStatus(repository: projects, events: events),
        rowsCounter: RowsCounter(settings: settings, events: events),
        tracker: WorkSessionTracker(sessions: sessions, clock: clock),
      );
      await broken.load();
      broken.completeRow();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(broken.state.saveFailed, isTrue);
      throwing.explode = false;
      broken.completeRow();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(broken.state.saveFailed, isFalse);
      await broken.close();
      await cubit.close();
    });

    test('действия до загрузки ничего не делают', () async {
      final WeaveCubit cubit = create();
      cubit
        ..completeRow()
        ..nextBead()
        ..back()
        ..setMode(WeaveMode.byBead)
        ..toggleSymbols()
        ..stepForward();
      expect(cubit.state.status, WeaveStatus.loading);
      await cubit.close();
    });

    test('учёт времени: сессия идёт с загрузки, пауза закрывает, возвращение открывает, закрытие завершает', () async {
      final WeaveCubit cubit = await loaded();
      await Future<void>.delayed(Duration.zero);
      expect(sessions.sessions, hasLength(1));
      clock.advance(const Duration(minutes: 2));
      await cubit.pause();
      expect(sessions.sessions['ws-1']!.duration, const Duration(minutes: 2));
      clock.advance(const Duration(minutes: 10));
      await cubit.resume();
      clock.advance(const Duration(minutes: 1));
      await cubit.close();
      expect(sessions.sessions, hasLength(2));
      expect(sessions.sessions['ws-2']!.duration, const Duration(minutes: 1));
    });
  });
}

class _FailingProgress extends FakeGridProgressStore {
  @override
  Future<Result<GridProgress>> load(String patternId) async => const Err<GridProgress>(StorageFailure('boom'));
}

class _ThrowingProgress extends FakeGridProgressStore {
  bool explode = true;

  @override
  Future<Result<void>> markRow(String patternId, int row) {
    if (explode) {
      throw StateError('boom');
    }
    return super.markRow(patternId, row);
  }
}
