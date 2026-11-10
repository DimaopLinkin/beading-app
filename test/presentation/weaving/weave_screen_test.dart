import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/image_pattern/book_work/record_book_progress.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/change_project_status.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:beading/domain/weaving/rows_counter.dart';
import 'package:beading/domain/weaving/work_session_tracker.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:beading/presentation/weaving/weave_cubit.dart';
import 'package:beading/presentation/weaving/weave_screen.dart';
import 'package:beading/presentation/weaving/weave_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/fake_work_sessions.dart';

/// 16 × 40: много рядов, чтобы автоскролл к текущему ряду был виден.
GridPattern _pattern(String projectId, {GridGeometry geometry = const GridGeometry.rectangular()}) => GridPattern(
  id: 'pat-1',
  projectId: projectId,
  geometry: geometry,
  metrics: BeadSize.delica11,
  grid: Grid.fromCells(width: 16, height: 40, cells: List<int>.generate(16 * 40, (i) => i % 3 == 0 ? 2 : 1)),
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
  late String projectId;

  setUp(() async {
    projects = FakeProjectRepository();
    patterns = FakeGridPatternRepository();
    progress = FakeGridProgressStore();
    settings = FakeSettingsRepository();
    sessions = FakeWorkSessionRepository();
    clock = FakeClock(DateTime.utc(2026, 11, 10, 9));
    events = BroadcastAppEvents();
    projectId = (await CreateProject(repository: projects, ids: FakeIdGenerator(), clock: clock)(
      name: 'Браслет',
    )).valueOrNull!.id;
    patterns.byProject[projectId] = _pattern(projectId);
  });

  tearDown(() => events.dispose());

  WeaveCubit newCubit() {
    final ChangeProjectStatus change = ChangeProjectStatus(repository: projects, events: events);
    return WeaveCubit(
      projectId: projectId,
      projects: projects,
      patterns: patterns,
      progress: progress,
      settings: settings,
      recordProgress: RecordBookProgress(
        projects: projects,
        changeStatus: change,
        touch: TouchProject(repository: projects, clock: clock),
      ),
      changeStatus: change,
      rowsCounter: RowsCounter(settings: settings, events: events),
      tracker: WorkSessionTracker(sessions: sessions, clock: clock, events: events),
      toastDuration: const Duration(seconds: 3),
    );
  }

  Widget app(WeaveCubit cubit, CupertinoThemeData theme) => CupertinoApp(
    theme: theme,
    builder: AppTheme.builder,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<WeaveCubit>.value(value: cubit, child: const WeaveScreen()),
  );

  Future<WeaveCubit> open(
    WidgetTester tester, {
    CupertinoThemeData? theme,
    Size size = const Size(430, 932),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final WeaveCubit cubit = newCubit();
    await tester.pumpWidget(app(cubit, theme ?? AppTheme.light));
    await tester.runAsync(cubit.load);
    await tester.pump();
    await tester.pump();
    return cubit;
  }

  Future<void> closeScreen(WidgetTester tester, WeaveCubit cubit) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(cubit.close);
  }

  testWidgets('загрузка и сбой: индикатор, затем экран; нет схемы — сообщение и «Закрыть»', (tester) async {
    patterns.byProject.clear();
    final WeaveCubit cubit = newCubit();
    await tester.pumpWidget(app(cubit, AppTheme.light));
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    await tester.runAsync(cubit.load);
    await tester.pump();
    expect(find.text('Не получилось открыть схему. Попробуй ещё раз.'), findsOneWidget);
    expect(find.text('Закрыть'), findsOneWidget);
    await tester.tap(find.text('Закрыть'));
    await tester.pump();
    await closeScreen(tester, cubit);
  });

  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('главный вид в теме ${theme.brightness}: счётчик, word chart со стрелкой, крупные кнопки', (
      tester,
    ) async {
      final WeaveCubit cubit = await open(tester, theme: theme);

      expect(find.text('Браслет'), findsOneWidget);
      expect(find.text('Ряд 1 из 40'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('weave-word-chart')), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.arrow_right), findsOneWidget);
      expect(find.text('Ряд готов'), findsOneWidget);
      // Крупный счётчик: не мельче 40 pt (принятый стиль 01b).
      final Text counter = tester.widget(find.byKey(const ValueKey<String>('weave-counter')));
      expect(counter.style!.fontSize, 40);
      for (final String key in <String>['weave-back', 'weave-next']) {
        final Size size = tester.getSize(find.byKey(ValueKey<String>(key)));
        expect(size.height, greaterThanOrEqualTo(56), reason: key);
        expect(size.width, greaterThanOrEqualTo(56), reason: key);
      }
      await closeScreen(tester, cubit);
    });
  }

  testWidgets('«Ряд готов» двигает счётчик, показывает тост; «Отменить» возвращает; тост гаснет сам', (tester) async {
    final WeaveCubit cubit = await open(tester);

    await tester.tap(find.byKey(const ValueKey<String>('weave-next')));
    await tester.pump();
    expect(find.text('Ряд 2 из 40'), findsOneWidget);
    expect(find.text('Ряд 1 готов'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('weave-undo')));
    await tester.pump();
    expect(find.text('Ряд 1 из 40'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('weave-toast')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('weave-next')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const ValueKey<String>('weave-toast')), findsNothing);
    await closeScreen(tester, cubit);
  });

  testWidgets('«назад» недоступна на первом ряду и работает после отметки', (tester) async {
    final WeaveCubit cubit = await open(tester);
    expect(tester.widget<CupertinoButton>(find.byKey(const ValueKey<String>('weave-back'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey<String>('weave-next')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('weave-back')));
    await tester.pump();
    expect(find.text('Ряд 1 из 40'), findsOneWidget);
    await closeScreen(tester, cubit);
  });

  testWidgets('по бусине: кнопки «Следующая бусина» и «Ряд готов», счётчик бусин', (tester) async {
    final WeaveCubit cubit = await open(tester);
    await tester.tap(find.text('По бусине'));
    await tester.pump();
    expect(find.text('Следующая бусина'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('weave-row-done')), findsOneWidget);
    expect(find.text('0/16'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('weave-next')));
    await tester.pump();
    expect(find.text('1/16'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('weave-row-done')));
    await tester.pump();
    expect(find.text('Ряд 2 из 40'), findsOneWidget);
    await tester.tap(find.text('По ряду'));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('weave-row-done')), findsNothing);
    await closeScreen(tester, cubit);
  });

  testWidgets('переключатель «Aa» показывает буквы символов в word chart', (tester) async {
    final WeaveCubit cubit = await open(tester);
    expect(find.text('A'), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('weave-symbols')));
    await tester.pump();
    expect(cubit.state.showSymbols, isTrue);
    expect(find.text('A'), findsWidgets);
    await closeScreen(tester, cubit);
  });

  testWidgets('клавиши: стрелка вниз и пробел — дальше, стрелка вверх — назад', (tester) async {
    final WeaveCubit cubit = await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(cubit.state.row, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(cubit.state.row, 1);
    await closeScreen(tester, cubit);
  });

  testWidgets('свайп вверх по счётчику — дальше, вниз — назад', (tester) async {
    final WeaveCubit cubit = await open(tester);
    await tester.fling(find.byKey(const ValueKey<String>('weave-swipe-area')), const Offset(0, -80), 1000);
    await tester.pump();
    expect(cubit.state.row, 1);
    await tester.fling(find.byKey(const ValueKey<String>('weave-swipe-area')), const Offset(0, 80), 1000);
    await tester.pump();
    expect(cubit.state.row, 0);
    // Медленный свайп не считается.
    await tester.drag(find.byKey(const ValueKey<String>('weave-swipe-area')), const Offset(0, -10));
    await tester.pump();
    await closeScreen(tester, cubit);
  });

  testWidgets('вибрация на завершение ряда', (tester) async {
    final List<String> haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final WeaveCubit cubit = await open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('weave-next')));
    await tester.pump();
    expect(haptics, <String>['HapticFeedbackType.lightImpact']);
    await closeScreen(tester, cubit);
  });

  testWidgets('автоскролл: после отметки далёкого ряда он остаётся в окне', (tester) async {
    final WeaveCubit cubit = await open(tester);
    for (int i = 0; i < 25; i++) {
      cubit.completeRow();
    }
    await tester.pump();
    await tester.pump();
    expect(find.text('Ряд 26 из 40'), findsOneWidget);
    final Rect schemeArea = tester.getRect(find.byKey(const ValueKey<String>('grid-touch')));
    // Окно схемы не пустое и маркер текущего ряда виден в нём.
    final Finder marker = find.byKey(const ValueKey<String>('grid-row-marker'));
    expect(marker, findsOneWidget);
    expect(schemeArea.overlaps(tester.getRect(marker)), isTrue);
    await closeScreen(tester, cubit);
  });

  testWidgets('последний ряд: предложение «готово», «Готово» завершает проект, «Позже» прячет', (tester) async {
    patterns.byProject[projectId] = GridPattern(
      id: 'pat-1',
      projectId: projectId,
      geometry: const GridGeometry.rectangular(),
      metrics: BeadSize.delica11,
      grid: Grid.fromCells(width: 2, height: 1, cells: const <int>[1, 2]),
      palette: samplePalette(),
    );
    final WeaveCubit cubit = await open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('weave-next')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('weave-finish-yes')), findsOneWidget);
    expect(tester.widget<CupertinoButton>(find.byKey(const ValueKey<String>('weave-next'))).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey<String>('weave-finish-later')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('weave-finish-yes')), findsNothing);

    cubit
      ..back()
      ..completeRow();
    await tester.pump();
    await tester.runAsync(cubit.finishProject);
    await tester.pump();
    expect(projects.projects[projectId]!.status, ProjectStatus.done);
    await closeScreen(tester, cubit);
  });

  testWidgets('жизненный цикл: уход в фон ставит время на паузу, возвращение — снимает', (tester) async {
    final WeaveCubit cubit = await open(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(sessions.sessions, hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(sessions.sessions, hasLength(2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await closeScreen(tester, cubit);
  });

  testWidgets('пейот и кирпич открываются без ошибок, ряд подсвечен', (tester) async {
    for (final GridGeometry geometry in <GridGeometry>[const GridGeometry.peyote(), const GridGeometry.brick()]) {
      patterns.byProject[projectId] = _pattern(projectId, geometry: geometry);
      final WeaveCubit cubit = await open(tester);
      expect(find.byKey(const ValueKey<String>('grid-overlay')), findsOneWidget);
      expect(cubit.state.status, WeaveStatus.ready);
      await tester.tap(find.byKey(const ValueKey<String>('weave-next')));
      await tester.pump();
      await closeScreen(tester, cubit);
    }
  });

  testWidgets('крупный шрифт Dynamic Type (AX3): счётчик помещается без переполнения', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final WeaveCubit cubit = newCubit();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(430, 932), textScaler: TextScaler.linear(2.5)),
        child: app(cubit, AppTheme.light),
      ),
    );
    await tester.runAsync(cubit.load);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    await closeScreen(tester, cubit);
  });
}
