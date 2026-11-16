import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/stats/load_project_stats.dart';
import 'package:beading/domain/stats/load_stats_overview.dart';
import 'package:beading/domain/stats/project_progress.dart';
import 'package:beading/domain/weaving/work_session.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/stats/project_stats_cubit.dart';
import 'package:beading/presentation/stats/project_stats_sheet.dart';
import 'package:beading/presentation/stats/stats_cubit.dart';
import 'package:beading/presentation/stats/stats_screen.dart';
import 'package:beading/presentation/stats/time_bar_chart.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_work_sessions.dart';

Project _project(String id, Craft craft, {ProjectStatus status = ProjectStatus.inProgress}) => Project(
  id: id,
  name: 'Работа $id',
  status: status,
  craft: craft,
  technique: Technique.defaultFor(craft),
  contentKind: ContentKind.grid,
  notes: '',
  coverPath: null,
  lastWorkedAt: DateTime.utc(2026),
);

void main() {
  late FakeProjectRepository projects;
  late FakeWorkSessionRepository sessions;
  late FakeGridPatternRepository patterns;
  late FakeCellProgressStore cells;
  late FakeClock clock;

  setUp(() {
    projects = FakeProjectRepository();
    sessions = FakeWorkSessionRepository();
    patterns = FakeGridPatternRepository();
    cells = FakeCellProgressStore();
    clock = FakeClock(DateTime(2026, 11, 15, 22));
  });

  ProjectProgressReader reader() =>
      ProjectProgressReader(patterns: patterns, rows: FakeGridProgressStore(), cells: cells);

  Future<void> work(String project, DateTime start, Duration length) async {
    final WorkSession s = (await sessions.start(project, start)).valueOrNull!;
    await sessions.touch(s.id, start.add(length));
  }

  Widget app(Widget home, {CupertinoThemeData theme = AppTheme.light, double textScale = 1}) => CupertinoApp(
    theme: theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: AppTheme.builder(context, child),
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ru'),
    home: home,
  );

  Future<StatsCubit> pumpStats(
    WidgetTester tester, {
    CupertinoThemeData theme = AppTheme.light,
    double textScale = 1,
    List<String>? opened,
  }) async {
    final StatsCubit cubit = StatsCubit(
      load: LoadStatsOverview(projects: projects, sessions: sessions, progress: reader(), clock: clock),
      sessions: sessions,
      clock: clock,
    );
    addTearDown(cubit.close);
    await tester.binding.setSurfaceSize(const Size(428, 926));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        BlocProvider<StatsCubit>.value(
          value: cubit,
          child: StatsScreen(onOpenProject: (_, p) => opened?.add(p.id)),
        ),
        theme: theme,
        textScale: textScale,
      ),
    );
    await cubit.load();
    await tester.pumpAndSettle();
    return cubit;
  }

  group('экран «Статистика»', () {
    for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
      testWidgets('итоги, график и список работ, вышивка первой (${theme.brightness})', (tester) async {
        projects.projects['x'] = _project('x', Craft.crossStitch);
        projects.projects['b'] = _project('b', Craft.beading);
        patterns.byProject['x'] = sampleGridPattern(projectId: 'x');
        await work('b', DateTime(2026, 11, 10, 9), const Duration(hours: 1));
        await work('x', DateTime(2026, 11, 11, 9), const Duration(hours: 1));
        await pumpStats(tester, theme: theme);

        expect(find.text('Статистика'), findsWidgets);
        expect(find.text('Эта неделя'), findsOneWidget);
        expect(find.text('2 ч'), findsOneWidget, reason: 'всего времени');
        expect(find.text('Дней с работой'), findsOneWidget);
        expect(find.text('Время по дням'), findsOneWidget);
        expect(find.text('ПО РАБОТАМ'), findsOneWidget);
        final double first = tester.getTopLeft(find.text('Работа x')).dy;
        final double second = tester.getTopLeft(find.text('Работа b')).dy;
        expect(first, lessThan(second), reason: 'при равном времени вышивка выше бисера');
      });
    }

    testWidgets('пустая статистика: подсказка, как считается время', (tester) async {
      await pumpStats(tester);
      await tester.tap(find.text('Всё время').first);
      await tester.pumpAndSettle();
      expect(find.text('Работы пока не было'), findsOneWidget);
      expect(find.textContaining('Время считается'), findsOneWidget);
    });

    testWidgets('период без работы, стрелки листают, вперёд из текущего нельзя', (tester) async {
      projects.projects['b'] = _project('b', Craft.beading);
      await work('b', DateTime(2026, 11, 3, 9), const Duration(hours: 2));
      await pumpStats(tester);
      expect(find.text('В этом периоде работы не было'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Предыдущий период'));
      await tester.pumpAndSettle();
      expect(find.text('Прошлая неделя'), findsOneWidget);
      expect(find.text('2 ч'), findsWidgets);
    });

    testWidgets('нажатие на работу открывает её статистику', (tester) async {
      projects.projects['b'] = _project('b', Craft.beading);
      await work('b', DateTime(2026, 11, 10, 9), const Duration(hours: 1));
      final List<String> opened = <String>[];
      await pumpStats(tester, opened: opened);
      await tester.tap(find.text('Работа b'));
      expect(opened, <String>['b']);
    });

    testWidgets('крупный текст AX3 не ломает вёрстку', (tester) async {
      projects.projects['x'] = _project('x', Craft.crossStitch);
      patterns.byProject['x'] = sampleGridPattern(projectId: 'x');
      await work('x', DateTime(2026, 11, 10, 9), const Duration(hours: 3, minutes: 7));
      await pumpStats(tester, textScale: 2.5);
      expect(tester.takeException(), isNull);
      expect(find.text('Всего времени'), findsOneWidget);
    });

    testWidgets('нажатие на столбик показывает выноску со временем', (tester) async {
      projects.projects['b'] = _project('b', Craft.beading);
      await work('b', DateTime(2026, 11, 10, 9), const Duration(hours: 1));
      await pumpStats(tester);
      final Rect chart = tester.getRect(find.byType(TimeBarChart));
      await tester.tapAt(Offset(chart.left + (chart.width - 44) / 7 * 1.5, chart.center.dy));
      await tester.pump();
      expect(find.textContaining('1 ч,'), findsOneWidget);
    });
  });

  group('лист «Статистика проекта»', () {
    Future<void> pumpSheet(WidgetTester tester, String id, {double textScale = 1}) async {
      final ProjectStatsCubit cubit = ProjectStatsCubit(
        projectId: id,
        load: LoadProjectStats(projects: projects, sessions: sessions, progress: reader(), clock: clock),
      );
      addTearDown(cubit.close);
      await tester.binding.setSurfaceSize(const Size(428, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        app(
          BlocProvider<ProjectStatsCubit>.value(
            value: cubit,
            child: ProjectStatsSheet(now: clock.now()),
          ),
          textScale: textScale,
        ),
      );
      await cubit.load();
      await tester.pumpAndSettle();
    }

    testWidgets('вышивка в работе: время, прогресс и темп', (tester) async {
      projects.projects['x'] = _project('x', Craft.crossStitch);
      patterns.byProject['x'] = sampleGridPattern(projectId: 'x');
      await cells.setCells('pat-1', const <CellPosition>[CellPosition(0, 0), CellPosition(1, 0)], done: true);
      await work('x', DateTime(2026, 11, 14, 9), const Duration(hours: 1));
      await work('x', DateTime(2026, 11, 15, 9), const Duration(hours: 2));
      await pumpSheet(tester, 'x');
      expect(find.text('Статистика проекта'), findsOneWidget);
      expect(find.text('3 ч'), findsOneWidget);
      expect(find.text('Сессий'), findsOneWidget);
      expect(find.textContaining('крестиков в час'), findsOneWidget);
      expect(find.text('Это оценка: темп бывает разным.'), findsOneWidget);
      expect(find.text('Сегодня'), findsOneWidget);
      expect(find.text('Вчера'), findsOneWidget);
    });

    testWidgets('мало данных: «Пока рано считать»', (tester) async {
      projects.projects['x'] = _project('x', Craft.crossStitch);
      patterns.byProject['x'] = sampleGridPattern(projectId: 'x');
      await work('x', DateTime(2026, 11, 15, 9), const Duration(minutes: 30));
      await pumpSheet(tester, 'x');
      expect(find.text('Пока рано считать'), findsOneWidget);
    });

    testWidgets('законченная работа: «Закончено: … за … дн.»', (tester) async {
      projects.projects['x'] = _project('x', Craft.crossStitch, status: ProjectStatus.done);
      patterns.byProject['x'] = sampleGridPattern(projectId: 'x');
      await work('x', DateTime(2026, 11, 10, 9), const Duration(hours: 2));
      await work('x', DateTime(2026, 11, 12, 9), const Duration(hours: 2));
      await pumpSheet(tester, 'x');
      expect(find.text('Закончено: 4 ч за 3 дня'), findsOneWidget);
    });

    testWidgets('проект без сессий: «Пока нет времени»', (tester) async {
      projects.projects['b'] = _project('b', Craft.beading);
      patterns.byProject['b'] = sampleGridPattern(projectId: 'b');
      await pumpSheet(tester, 'b');
      expect(find.text('Пока нет времени'), findsOneWidget);
      expect(find.text('Темп'), findsNothing);
    });

    testWidgets('бисер без отмеченных рядов: «Не начато», AX3 без ошибок', (tester) async {
      projects.projects['b'] = _project('b', Craft.beading);
      patterns.byProject['b'] = sampleGridPattern(projectId: 'b');
      await work('b', DateTime(2026, 11, 15, 9), const Duration(hours: 3));
      await pumpSheet(tester, 'b', textScale: 2.5);
      expect(tester.takeException(), isNull);
      expect(find.text('Не начато'), findsOneWidget);
    });
  });
}
