import 'package:beading/core/failure.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/pattern_generation/pattern_template.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/presentation/grid_pattern/grid_pattern_view.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/pattern_template/pattern_template_cubit.dart';
import 'package:beading/presentation/pattern_template/pattern_template_screen.dart';
import 'package:beading/presentation/pattern_template/pattern_template_state.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_settings_repository.dart';

void main() {
  late FakeCatalogRepository catalog;
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;

  setUp(() {
    catalog = FakeCatalogRepository(<CatalogColor>[
      catalogColor('1', 'Navy', '#1f3a8a'),
      catalogColor('2', 'Cream', '#f5e9c8'),
      catalogColor('3', 'Red', '#cc0000'),
      catalogColor('4', 'Black', '#000000'),
      catalogColor('8', 'White', '#ffffff'),
    ]);
    projects = FakeProjectRepository();
    patterns = FakeGridPatternRepository();
  });

  PatternTemplateCubit buildCubit() {
    final FakeIdGenerator ids = FakeIdGenerator();
    return PatternTemplateCubit(
      catalog: catalog,
      settings: FakeSettingsRepository(),
      createPattern: CreateGridPattern(
        createProject: CreateProject(repository: projects, ids: ids, clock: FakeClock(DateTime.utc(2026, 11, 10))),
        projects: projects,
        patterns: patterns,
        ids: ids,
      ),
      brandSetting: SettingKeys.defaultBeadBrand,
    );
  }

  /// Экран открывают поверх библиотеки, чтобы проверить, с каким результатом он закрывается.
  Future<({PatternTemplateCubit cubit, ValueNotifier<String?> result})> pumpScreen(
    WidgetTester tester, {
    CupertinoThemeData theme = AppTheme.light,
    bool start = true,
  }) async {
    tester.view
      ..physicalSize = const Size(430, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final PatternTemplateCubit cubit = buildCubit();
    addTearDown(cubit.close);
    final ValueNotifier<String?> result = ValueNotifier<String?>(null);
    await tester.pumpWidget(
      CupertinoApp(
        theme: theme,
        builder: AppTheme.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async {
              result.value = await Navigator.of(context).push<String>(
                CupertinoPageRoute<String>(
                  builder: (_) => BlocProvider<PatternTemplateCubit>.value(
                    value: cubit,
                    child: const PatternTemplateScreen(),
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // Индикатор загрузки крутится бесконечно, поэтому ждём только переход.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    if (start) {
      await cubit.start();
      await tester.pump();
    }
    return (cubit: cubit, result: result);
  }

  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('галерея, предпросмотр, параметры и цвета, тема ${theme.brightness}', (tester) async {
      await pumpScreen(tester, theme: theme);

      expect(find.text('Узор по шаблону'), findsOneWidget);
      // Галерея прокручивается: сразу построены первые карточки, остальные доступны прокруткой.
      for (final String kind in <String>['Полосы', 'Зигзаг', 'Ромбы']) {
        expect(find.text(kind), findsWidgets, reason: kind);
      }
      await tester.drag(find.byKey(const ValueKey<String>('template-stripes')), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Бордюр'), findsOneWidget);
      expect(find.byType(GridPatternView), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('template-color-0')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('template-color-1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('template-add-color')), findsOneWidget);
      expect(find.text('Бусин в ряду'), findsOneWidget);
      expect(find.text('Ширина полосы'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('пока каталог грузится — индикатор, «Сохранить» недоступно', (tester) async {
    await pumpScreen(tester, start: false);

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    final CupertinoButton save = tester.widget<CupertinoButton>(find.byKey(const ValueKey<String>('template-save')));
    expect(save.onPressed, isNull);
  });

  testWidgets('каталог недоступен — сообщение и «Повторить»', (tester) async {
    catalog.fail = true;
    final ctx = await pumpScreen(tester);

    expect(find.text('Каталог цветов недоступен. Попробуйте ещё раз.'), findsOneWidget);

    catalog.fail = false;
    await tester.tap(find.byKey(const ValueKey<String>('template-retry')));
    await tester.pump();
    await tester.pump();
    expect(ctx.cubit.state.status, TemplateStatus.ready);
    expect(find.byType(GridPatternView), findsOneWidget);
  });

  testWidgets('нажатие на карточку шаблона меняет предпросмотр и показывает его параметры', (tester) async {
    final ctx = await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey<String>('template-zigzag')));
    await tester.pump();

    expect(ctx.cubit.state.params.kind, TemplateKind.zigzag);
    expect(find.text('Размах зигзага'), findsOneWidget);
    expect(find.text('Ширина полосы'), findsNothing);
  });

  testWidgets('кнопки «+» и «−» меняют размер и предпросмотр, на границе выключаются', (tester) async {
    final ctx = await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey<String>('plus-Бусин в ряду')));
    await tester.pump();
    expect(ctx.cubit.state.params.width, 13);
    expect(ctx.cubit.state.preview!.grid.width, 13);
    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('value-Бусин в ряду'))).data, '13');

    ctx.cubit.setParams(ctx.cubit.state.params.copyWith(width: TemplateParams.minSide));
    await tester.pump();
    final CupertinoButton minus = tester.widget<CupertinoButton>(
      find.byKey(const ValueKey<String>('minus-Бусин в ряду')),
    );
    expect(minus.onPressed, isNull);
  });

  testWidgets('выбор цвета из листа заменяет цвет; поиск по названию и артикулу', (tester) async {
    final ctx = await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey<String>('template-color-0')));
    await tester.pumpAndSettle();
    expect(find.text('Выберите цвет'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey<String>('template-color-search')), 'red');
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('template-pick-3')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('template-pick-1')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey<String>('template-color-search')), 'нет такого');
    await tester.pump();
    expect(find.text('Ничего не найдено'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey<String>('template-color-search')), '3');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('template-pick-3')));
    await tester.pumpAndSettle();

    expect(ctx.cubit.state.colors.first.name, 'Red');
    expect(find.text('Выберите цвет'), findsNothing);
  });

  testWidgets('в полосах цвет можно добавить и убрать; убрать нельзя, когда их два', (tester) async {
    final ctx = await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey<String>('template-add-color')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('template-remove-color')), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('template-pick-3')));
    await tester.pumpAndSettle();
    expect(ctx.cubit.state.colors, hasLength(3));

    await tester.tap(find.byKey(const ValueKey<String>('template-color-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('template-remove-color')));
    await tester.pumpAndSettle();
    expect(ctx.cubit.state.colors, hasLength(2));

    await tester.tap(find.byKey(const ValueKey<String>('template-color-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('template-remove-color')), findsNothing);
  });

  testWidgets('в других шаблонах видны только два цвета и нет «Добавить цвет»', (tester) async {
    await pumpScreen(tester);

    await tester.ensureVisible(find.byKey(const ValueKey<String>('template-checker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('template-checker')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('template-color-1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('template-color-2')), findsNothing);
    expect(find.byKey(const ValueKey<String>('template-add-color')), findsNothing);
  });

  testWidgets('симметрия в мозаике предупреждает о приблизительном отражении; на станке — нет', (tester) async {
    final ctx = await pumpScreen(tester);
    const Key note = ValueKey<String>('template-symmetry-note');

    ctx.cubit.setParams(ctx.cubit.state.params.copyWith(symmetry: PatternSymmetry.horizontal));
    await tester.pumpAndSettle();
    expect(find.byKey(note), findsNothing);

    ctx.cubit.setParams(ctx.cubit.state.params.copyWith(technique: Technique.peyote));
    await tester.pumpAndSettle();
    expect(find.byKey(note), findsOneWidget);

    ctx.cubit.setParams(ctx.cubit.state.params.copyWith(symmetry: PatternSymmetry.none));
    await tester.pumpAndSettle();
    expect(find.byKey(note), findsNothing);
  });

  testWidgets('«Сохранить» создаёт проект и закрывает экран с его id; название по умолчанию', (tester) async {
    final ctx = await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey<String>('template-save')));
    await tester.pumpAndSettle();

    final String id = ctx.result.value!;
    expect(projects.projects[id]!.name, 'Полосы 12×40');
    expect(patterns.byProject[id], isNotNull);
    expect(find.text('Узор по шаблону'), findsNothing, reason: 'экран закрыт');
  });

  testWidgets('своё название попадает в проект', (tester) async {
    final ctx = await pumpScreen(tester);

    await tester.enterText(find.byKey(const ValueKey<String>('template-name')), 'Подарок Насте');
    await tester.tap(find.byKey(const ValueKey<String>('template-save')));
    await tester.pumpAndSettle();

    expect(projects.projects[ctx.result.value]!.name, 'Подарок Насте');
  });

  testWidgets('ошибка сохранения: сообщение, экран остаётся', (tester) async {
    patterns.failNextSave = const StorageFailure('boom');
    final ctx = await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey<String>('template-save')));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось сохранить узор. Попробуйте ещё раз.'), findsOneWidget);
    expect(ctx.result.value, isNull);
    expect(find.text('Узор по шаблону'), findsOneWidget);
  });

  testWidgets('предпросмотр закреплён: при прокрутке параметров остаётся на экране', (tester) async {
    tester.view
      ..physicalSize = const Size(430, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final PatternTemplateCubit cubit = buildCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      CupertinoApp(
        theme: AppTheme.light,
        builder: AppTheme.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: BlocProvider<PatternTemplateCubit>.value(value: cubit, child: const PatternTemplateScreen()),
      ),
    );
    await cubit.start();
    await tester.pump();
    await tester.pump();

    final Rect before = tester.getRect(find.byKey(const ValueKey<String>('template-preview')));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
    await tester.pump();

    expect(tester.getRect(find.byKey(const ValueKey<String>('template-preview'))), before);
  });

  testWidgets('техника выбирается системным листом действий', (tester) async {
    final ctx = await pumpScreen(tester);

    await tester.tap(find.widgetWithText(CupertinoListTile, 'Техника'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.text('Мозаика'));
    await tester.pumpAndSettle();

    expect(ctx.cubit.state.params.technique, Technique.peyote);
    expect(find.byType(CupertinoActionSheet), findsNothing);
  });

  testWidgets('лист выбора цвета — системный лист со списком каталога', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey<String>('template-color-0')));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoListTile), findsWidgets);
    expect(find.byKey(const ValueKey<String>('template-pick-3')), findsOneWidget);
  });

  testWidgets('крупный шрифт не ломает вёрстку', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpScreen(tester);

    expect(tester.takeException(), isNull);
  });
}
