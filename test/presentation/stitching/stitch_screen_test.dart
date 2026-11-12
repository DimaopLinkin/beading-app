import 'package:beading/core/failure.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/use_cases/cell_progress_commands.dart';
import 'package:beading/domain/image_pattern/book_work/record_book_progress.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/change_project_status.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:beading/domain/weaving/work_session_tracker.dart';
import 'package:beading/presentation/grid_pattern/grid_pattern_view.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/stitching/stitch_canvas.dart';
import 'package:beading/presentation/stitching/stitch_cubit.dart';
import 'package:beading/presentation/stitching/stitch_screen.dart';
import 'package:beading/presentation/stitching/stitch_state.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/fake_work_sessions.dart';

/// 10 × 10, цвета по шахматке: по 50 клеток.
GridPattern _pattern(String projectId) => GridPattern(
  id: 'pat-1',
  projectId: projectId,
  geometry: const GridGeometry.rectangular(),
  metrics: BeadSize.delica11,
  grid: Grid.fromCells(width: 10, height: 10, cells: List<int>.generate(100, (i) => (i + i ~/ 10) % 2 + 1)),
  palette: samplePalette(),
);

void main() {
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;
  late FakeCellProgressStore cells;
  late FakeClock clock;
  late BroadcastAppEvents events;
  late String projectId;
  late FakeSettingsRepository settings;
  late FakeWorkSessionRepository sessions;
  late FakeGridProgressStore rows;

  setUp(() async {
    projects = FakeProjectRepository();
    patterns = FakeGridPatternRepository();
    cells = FakeCellProgressStore(width: 10);
    rows = FakeGridProgressStore();
    settings = FakeSettingsRepository();
    sessions = FakeWorkSessionRepository();
    clock = FakeClock(DateTime.utc(2026, 11, 11, 9));
    events = BroadcastAppEvents();
    projectId = (await CreateProject(repository: projects, ids: FakeIdGenerator(), clock: clock)(
      name: 'Котик',
    )).valueOrNull!.id;
    patterns.byProject[projectId] = _pattern(projectId);
  });

  tearDown(() => events.dispose());

  StitchCubit newCubit() {
    final ChangeProjectStatus change = ChangeProjectStatus(repository: projects, events: events);
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
        changeStatus: change,
        touch: TouchProject(repository: projects, clock: clock),
      ),
      changeStatus: change,
      tracker: WorkSessionTracker(sessions: sessions, clock: clock),
      events: events,
    );
  }

  Widget app(StitchCubit cubit, CupertinoThemeData theme, {VoidCallback? onOpenFloss}) => CupertinoApp(
    theme: theme,
    builder: AppTheme.builder,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<StitchCubit>.value(
      value: cubit,
      child: StitchScreen(onOpenFloss: onOpenFloss),
    ),
  );

  Future<StitchCubit> open(WidgetTester tester, {CupertinoThemeData? theme, VoidCallback? onOpenFloss}) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final StitchCubit cubit = newCubit();
    await tester.pumpWidget(app(cubit, theme ?? AppTheme.light, onOpenFloss: onOpenFloss));
    await tester.runAsync(cubit.load);
    await tester.pump();
    await tester.pump();
    return cubit;
  }

  Future<void> closeScreen(WidgetTester tester, StitchCubit cubit) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(cubit.close);
  }

  testWidgets('кнопка «Нитки» открывает расход; без колбэка её нет', (tester) async {
    int opened = 0;
    StitchCubit cubit = await open(tester, onOpenFloss: () => opened++);

    await tester.tap(find.byKey(const ValueKey<String>('stitch-floss')));
    await tester.pump();

    expect(opened, 1);
    await closeScreen(tester, cubit);

    cubit = await open(tester);
    expect(find.byKey(const ValueKey<String>('stitch-floss')), findsNothing);
    await closeScreen(tester, cubit);
  });

  testWidgets('нет схемы — сообщение и «Закрыть»', (tester) async {
    patterns.byProject.clear();
    final StitchCubit cubit = newCubit();
    await tester.pumpWidget(app(cubit, AppTheme.light));
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    await tester.runAsync(cubit.load);
    await tester.pump();
    expect(find.text('Не получилось открыть вышивку. Попробуй ещё раз.'), findsOneWidget);
    await tester.tap(find.text('Закрыть'));
    await tester.pump();
    await closeScreen(tester, cubit);
  });

  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('главный вид в теме ${theme.brightness}: название, процент, счётчик, остаток, инструменты', (
      tester,
    ) async {
      final StitchCubit cubit = await open(tester, theme: theme);
      expect(find.text('Котик'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Сделано 0 из 100'), findsOneWidget);
      expect(find.text('Осталось 100'), findsOneWidget);
      expect(find.text('Касание'), findsOneWidget);
      expect(find.text('Мазок'), findsOneWidget);
      expect(find.text('Область'), findsOneWidget);
      expect(find.text('Цвета'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('stitch-overlay')), findsOneWidget);
      await closeScreen(tester, cubit);
    });
  }

  testWidgets('касание клетки отмечает её, счётчик и процент растут', (tester) async {
    final StitchCubit cubit = await open(tester);
    final Offset center = tester.getCenter(find.byKey(const ValueKey<String>('stitch-overlay')));
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('Сделано 1 из 100'), findsOneWidget);
    expect(find.text('Осталось 99'), findsOneWidget);
    expect(find.text('1%'), findsOneWidget);
    await closeScreen(tester, cubit);
    expect(cells.calls, isNotEmpty);
  });

  testWidgets('широкий экран: боковая панель цветов и панель режимов сверху', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final StitchCubit cubit = newCubit();
    await tester.pumpWidget(app(cubit, AppTheme.light));
    await tester.runAsync(cubit.load);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('stitch-sidebar')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('stitch-color-0')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('stitch-colors')), findsNothing);
    await tester.tap(find.text('Область'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(cubit.state.tool, StitchTool.area);
    final bool blocks = cubit.state.showBlocks;
    await tester.tap(find.byKey(const ValueKey<String>('stitch-blocks')));
    await tester.pump();
    expect(cubit.state.showBlocks, !blocks);
    await closeScreen(tester, cubit);
  });

  testWidgets('очень крупный шрифт: режимы сеткой 2 × 2 и кнопка «Ещё» с остальными действиями', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view
      ..physicalSize = const Size(430, 932)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final StitchCubit cubit = newCubit();
    await tester.pumpWidget(app(cubit, AppTheme.light));
    await tester.runAsync(cubit.load);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('stitch-more')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('stitch-blocks')), findsNothing);
    final double tapY = tester.getCenter(find.byKey(const ValueKey<String>('stitch-tool-tap'))).dy;
    expect(tester.getCenter(find.byKey(const ValueKey<String>('stitch-tool-stroke'))).dy, tapY);
    expect(tester.getCenter(find.byKey(const ValueKey<String>('stitch-tool-area'))).dy, greaterThan(tapY));
    final bool blocks = cubit.state.showBlocks;
    await tester.tap(find.byKey(const ValueKey<String>('stitch-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Блоки'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(cubit.state.showBlocks, !blocks);
    await closeScreen(tester, cubit);
  });

  testWidgets('откат: кнопка «Отменить» и тост после мазка', (tester) async {
    final StitchCubit cubit = await open(tester);
    final Finder undo = find.byKey(const ValueKey<String>('stitch-undo'));
    expect(
      tester.widget<CupertinoButton>(undo).onPressed,
      isNull,
    );
    await tester.tap(find.text('Мазок'));
    await tester.pump(const Duration(milliseconds: 300));
    final Offset center = tester.getCenter(find.byKey(const ValueKey<String>('stitch-overlay')));
    final TestGesture finger = await tester.startGesture(center);
    await finger.moveBy(const Offset(40, 0));
    await finger.moveBy(const Offset(40, 0));
    await finger.up();
    await tester.pump();
    final int marked = cubit.state.done;
    expect(marked, greaterThan(1));
    expect(find.byKey(const ValueKey<String>('stitch-undo-toast')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('stitch-undo-toast-button')));
    await tester.pump();
    expect(cubit.state.done, 0);
    expect(find.byKey(const ValueKey<String>('stitch-undo-toast')), findsNothing);
    await closeScreen(tester, cubit);
  });

  testWidgets('мелкие клетки: касание не отмечает, показывает подсказку; мазок работает', (tester) async {
    patterns.byProject[projectId] = GridPattern(
      id: 'pat-2',
      projectId: projectId,
      geometry: const GridGeometry.rectangular(),
      metrics: BeadSize.delica11,
      grid: Grid.fromCells(width: 60, height: 60, cells: List<int>.generate(3600, (i) => i % 2 + 1)),
      palette: samplePalette(),
    );
    final StitchCubit cubit = await open(tester);
    expect(find.byKey(const ValueKey<String>('stitch-zoom-hint')), findsOneWidget);
    final Offset center = tester.getCenter(find.byKey(const ValueKey<String>('stitch-overlay')));
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('Сделано 1 из 3600'), findsNothing);
    expect(find.text('Приблизьте, чтобы отметить касанием'), findsOneWidget);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.descendant(of: find.byType(StitchCanvas), matching: find.byType(AnimatedOpacity)),
          )
          .opacity,
      1,
    );
    await tester.pump(const Duration(seconds: 3));
    await closeScreen(tester, cubit);
    expect(cells.calls, isEmpty);
  });

  testWidgets('знаки появляются раньше, чем клетку удобно отмечать касанием', (tester) async {
    patterns.byProject[projectId] = GridPattern(
      id: 'pat-3',
      projectId: projectId,
      geometry: const GridGeometry.rectangular(),
      metrics: BeadSize.delica11,
      grid: Grid.fromCells(width: 60, height: 60, cells: List<int>.generate(3600, (i) => i % 2 + 1)),
      palette: samplePalette(),
    );
    final StitchCubit cubit = await open(tester);
    StitchStyle style() => tester
        .widget<GridPatternView>(find.descendant(of: find.byType(StitchCanvas), matching: find.byType(GridPatternView)))
        .options
        .effectiveStitchStyle;
    expect(style(), StitchStyle.color, reason: 'вся схема в окне: клетки мелкие, знаков нет');

    final Offset center = tester.getCenter(find.byKey(const ValueKey<String>('stitch-overlay')));
    tester.binding.handlePointerEvent(PointerScaleEvent(position: center, scale: 2));
    await tester.pump();
    expect(style(), StitchStyle.colorAndSymbol, reason: 'клетка около 13 px: знак уже виден');
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('Приблизьте, чтобы отметить касанием'), findsOneWidget, reason: 'а касанием ещё не отметить');
    await tester.pump(const Duration(seconds: 3));
    await closeScreen(tester, cubit);
  });

  testWidgets('инструменты переключаются; мазок пальцем отмечает несколько клеток', (tester) async {
    final StitchCubit cubit = await open(tester);
    await tester.tap(find.text('Мазок'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(cubit.state.tool, StitchTool.stroke);
    final Offset center = tester.getCenter(find.byKey(const ValueKey<String>('stitch-overlay')));
    final TestGesture gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.up();
    await tester.pump();
    expect(cubit.state.done, greaterThan(1));
    await tester.tap(find.text('Область'));
    await tester.pump(const Duration(milliseconds: 300));
    final TestGesture drag = await tester.startGesture(center + const Offset(0, 80));
    await drag.moveBy(const Offset(40, 40));
    await tester.pump();
    expect(cubit.state.areaPreview, isNotNull);
    await drag.up();
    await tester.pump();
    expect(cubit.state.areaPreview, isNull);
    await closeScreen(tester, cubit);
  });

  testWidgets('долгое касание паркует клетку, кнопка «К месту остановки» появляется', (tester) async {
    final StitchCubit cubit = await open(tester);
    expect(find.byKey(const ValueKey<String>('stitch-go-parked')), findsOneWidget);
    final Offset center = tester.getCenter(find.byKey(const ValueKey<String>('stitch-overlay')));
    final TestGesture press = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 700));
    await press.up();
    await tester.pump();
    expect(cubit.state.parked, isNotNull);
    expect(find.text('К месту остановки'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('stitch-go-parked')));
    await tester.pump();
    await closeScreen(tester, cubit);
  });

  testWidgets('список цветов: остаток, подсветка касанием, отметка цвета целиком, предложение «Готово»', (
    tester,
  ) async {
    final StitchCubit cubit = await open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('stitch-colors')));
    await tester.pumpAndSettle();
    expect(find.text('Что осталось по цветам'), findsOneWidget);
    expect(find.text('0 из 50'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey<String>('stitch-mark-color-0')));
    await tester.pump();
    expect(find.text('Цвет готов'), findsOneWidget);
    expect(find.text('50 из 50'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('stitch-color-1')));
    await tester.pumpAndSettle();
    expect(cubit.state.highlight, 2);
    // Закрываем второй цвет — всё сделано.
    await tester.tap(find.byKey(const ValueKey<String>('stitch-colors')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('stitch-mark-color-1')));
    await tester.pump();
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.text('Вся вышивка сделана. Отметить работу законченной?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('stitch-finish-yes')));
    await tester.pump();
    expect(cubit.state.projectDone, isTrue);
    await closeScreen(tester, cubit);
    expect((await projects.get(projectId)).valueOrNull!.status, ProjectStatus.done);
  });

  testWidgets('сбой записи: уведомление; переключатели символов и блоков', (tester) async {
    final StitchCubit cubit = await open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('stitch-symbols')));
    await tester.tap(find.byKey(const ValueKey<String>('stitch-blocks')));
    await tester.pump();
    expect(cubit.state.showSymbols, isTrue);
    expect(cubit.state.showBlocks, isFalse);
    expect(find.byKey(const ValueKey<String>('stitch-overlay')), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('stitch-blocks')));
    await tester.pump();
    cells.failNextWrite = const StorageFailure('диск');
    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey<String>('stitch-overlay'))));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('stitch-save-failed')), findsOneWidget);
    await closeScreen(tester, cubit);
  });
}
