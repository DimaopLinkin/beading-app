import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/presentation/editor/new_grid_cubit.dart';
import 'package:beading/presentation/editor/new_grid_screen.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';

void main() {
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;
  late NewGridCubit cubit;
  String? closedWith;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    closedWith = null;
    projects = FakeProjectRepository();
    patterns = FakeGridPatternRepository();
    final FakeIdGenerator ids = FakeIdGenerator();
    cubit = NewGridCubit(
      defaultName: 'Новая схема',
      createPattern: CreateGridPattern(
        createProject: CreateProject(repository: projects, ids: ids, clock: FakeClock(DateTime.utc(2026))),
        projects: projects,
        patterns: patterns,
        ids: ids,
      ),
    );
    addTearDown(cubit.close);
  });

  void tall(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(600, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget wrap(CupertinoThemeData theme) => CupertinoApp(
    theme: theme,
    builder: AppTheme.builder,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => CupertinoButton(
        child: const Text('open'),
        onPressed: () async {
          closedWith = await Navigator.of(context).push<String>(
            CupertinoPageRoute<String>(
              builder: (_) => BlocProvider<NewGridCubit>.value(value: cubit, child: const NewGridScreen()),
            ),
          );
        },
      ),
    ),
  );

  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('лист создания в теме ${theme.brightness}: поля и предпросмотр в см', (tester) async {
      tall(tester);
      await tester.pumpWidget(wrap(theme));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Новая схема'), findsOneWidget);
      expect(find.text('Станок'), findsOneWidget);
      expect(find.text('Мозаика'), findsOneWidget);
      expect(find.text('Кирпичик'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('new-grid-size')), findsOneWidget);
      expect(find.textContaining('см'), findsOneWidget);
    });
  }

  testWidgets('шаги ширины меняют предпросмотр, «Создать» закрывает лист с id проекта', (tester) async {
    tall(tester);
    await tester.pumpWidget(wrap(AppTheme.light));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final String before = tester.widget<Text>(find.byKey(const ValueKey<String>('new-grid-size'))).data!;
    await tester.tap(find.byKey(const ValueKey<String>('width-plus')));
    await tester.pump();
    expect(cubit.state.width, 11);
    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('new-grid-size'))).data, isNot(before));

    await tester.tap(find.text('Мозаика'));
    await tester.pump();
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();

    expect(closedWith, isNotNull);
    expect(projects.projects[closedWith]!.name, 'Новая схема');
    expect(patterns.byProject[closedWith]!.grid.width, 11);
  });

  testWidgets('недопустимый размер: подсказка, «Создать» недоступна', (tester) async {
    tall(tester);
    await tester.pumpWidget(wrap(AppTheme.light));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey<String>('width-field')), '0');
    await tester.pump();

    expect(find.text('Размер: от 1 до 500 бусин по каждой стороне'), findsOneWidget);
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(closedWith, isNull);
    expect(projects.projects, isEmpty);
  });
}
