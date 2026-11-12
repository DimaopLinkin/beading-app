import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/presentation/editor/new_stitch_cubit.dart';
import 'package:beading/presentation/editor/new_stitch_screen.dart';
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
  late NewStitchCubit cubit;
  String? closedWith;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    closedWith = null;
    projects = FakeProjectRepository();
    patterns = FakeGridPatternRepository();
    final FakeIdGenerator ids = FakeIdGenerator();
    cubit = NewStitchCubit(
      defaultName: 'Новая вышивка',
      createPattern: CreateGridPattern(
        createProject: CreateProject(repository: projects, ids: ids, clock: FakeClock(DateTime.utc(2026))),
        projects: projects,
        patterns: patterns,
        ids: ids,
      ),
    );
    addTearDown(cubit.close);
  });

  Fabric aida(int count) => Fabric.create(kind: FabricKind.aida, count: count).valueOrNull!;

  group('NewStitchCubit', () {
    test('размер в сантиметрах переводится в крестики по канве', () {
      cubit.setFabric(aida(14));

      cubit
        ..setWidthCm(20)
        ..setHeightCm(10);

      // Аида 14: клетка 1,814 мм. 200 / 1,814 = 110,2; 100 / 1,814 = 55,1.
      expect(cubit.state.width, 110);
      expect(cubit.state.height, 55);
      expect(cubit.state.widthCm, closeTo(19.96, 0.01));
    });

    test('смена канвы оставляет размер в крестиках, меняется размер в см', () {
      cubit
        ..setWidth(100)
        ..setFabric(aida(14));
      final double before = cubit.state.widthCm;

      cubit.setFabric(aida(18));

      expect(cubit.state.width, 100);
      expect(cubit.state.widthCm, lessThan(before));
    });

    test('допустимый размер — от 1 до 500', () {
      cubit.setWidth(0);
      expect(cubit.state.validSize, isFalse);
      cubit
        ..setWidth(501)
        ..setHeight(10);
      expect(cubit.state.validSize, isFalse);
      cubit.setWidth(500);
      expect(cubit.state.validSize, isTrue);
      cubit.setWidthCm(0);
      expect(cubit.state.width, 0);
    });

    test('создаёт проект-вышивку и пустую схему на выбранной канве', () async {
      final Fabric linen = Fabric.create(
        kind: FabricKind.linen,
        count: 32,
        color: const Rgb(245, 239, 224),
      ).valueOrNull!;
      cubit
        ..setFabric(linen)
        ..setWidth(60)
        ..setHeight(40)
        ..setName(' Котик ');

      await cubit.create();

      final String id = cubit.state.projectId!;
      expect(projects.projects[id]!.craft, Craft.crossStitch);
      expect(projects.projects[id]!.name, 'Котик');
      final pattern = patterns.byProject[id]!;
      expect(pattern.metrics, linen);
      expect(pattern.grid.width, 60);
      expect(pattern.grid.height, 40);
      expect(pattern.palette.length, 0);
    });

    test('без названия берётся название по умолчанию; недопустимый размер не создаёт проект', () async {
      cubit.setWidth(0);
      await cubit.create();
      expect(projects.projects, isEmpty);

      cubit.setWidth(10);
      await cubit.create();
      expect(projects.projects[cubit.state.projectId]!.name, 'Новая вышивка');
    });
  });

  group('NewStitchScreen', () {
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
      locale: const Locale('ru'),
      home: Builder(
        builder: (context) => CupertinoButton(
          child: const Text('open'),
          onPressed: () async {
            closedWith = await Navigator.of(context).push<String>(
              CupertinoPageRoute<String>(
                builder: (_) => BlocProvider<NewStitchCubit>.value(value: cubit, child: const NewStitchScreen()),
              ),
            );
          },
        ),
      ),
    );

    for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
      testWidgets('лист создания в теме ${theme.brightness}: канва, цвет, размер и итог в см', (tester) async {
        tall(tester);
        await tester.pumpWidget(wrap(theme));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('Новая вышивка'), findsOneWidget);
        expect(find.text('Аида 14'), findsOneWidget);
        expect(find.text('Белая'), findsOneWidget);
        expect(find.text('Крестики'), findsOneWidget);
        expect(find.text('Сантиметры'), findsOneWidget);
        expect(find.textContaining('80 × 80 крестиков, на этой канве'), findsOneWidget);
      });
    }

    testWidgets('канва выбирается листом действий, размер — в сантиметрах', (tester) async {
      tall(tester);
      await tester.pumpWidget(wrap(AppTheme.light));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('new-stitch-fabric')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Аида 18'));
      await tester.pumpAndSettle();
      expect(cubit.state.fabric.count, 18);

      await tester.tap(find.text('Сантиметры'));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey<String>('width-field')), '12,5');
      await tester.pump();
      // Аида 18: клетка 1,411 мм; 125 / 1,411 = 88,6.
      expect(cubit.state.width, 89);
      expect(find.text('Ширина, см'), findsOneWidget);
    });

    testWidgets('«Создать» закрывает лист с id проекта вышивки', (tester) async {
      tall(tester);
      await tester.pumpWidget(wrap(AppTheme.light));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('new-stitch-fabric-color')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Чёрная'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();

      expect(closedWith, isNotNull);
      expect(projects.projects[closedWith]!.craft, Craft.crossStitch);
      expect((patterns.byProject[closedWith]!.metrics as Fabric).color, const Rgb(20, 20, 20));
    });

    testWidgets('недопустимый размер: подсказка, «Создать» недоступна', (tester) async {
      tall(tester);
      await tester.pumpWidget(wrap(AppTheme.light));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey<String>('width-field')), '0');
      await tester.pump();

      expect(find.text('Размер: от 1 до 500 крестиков по каждой стороне'), findsOneWidget);
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(closedWith, isNull);
    });
  });
}
