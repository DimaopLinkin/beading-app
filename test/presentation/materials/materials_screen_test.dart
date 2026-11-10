import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/cell_metrics_codec.dart';
import 'package:beading/domain/materials/use_cases/load_project_materials.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/materials/materials_cubit.dart';
import 'package:beading/presentation/materials/materials_screen.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_text_sharer.dart';
import 'materials_cubit_test.dart' show gridProject;

void main() {
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;
  late FakeTextSharer sharer;

  setUp(() {
    projects = FakeProjectRepository()..projects['proj-1'] = gridProject(name: 'Браслет Ёлка');
    patterns = FakeGridPatternRepository()..byProject['proj-1'] = sampleGridPattern();
    sharer = FakeTextSharer();
  });

  Future<MaterialsCubit> pumpScreen(
    WidgetTester tester, {
    CupertinoThemeData theme = AppTheme.light,
    Size size = const Size(430, 932),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final MaterialsCubit cubit = MaterialsCubit(
      projectId: 'proj-1',
      loadMaterials: LoadProjectMaterials(patterns),
      projects: projects,
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      CupertinoApp(
        theme: theme,
        builder: AppTheme.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: BlocProvider<MaterialsCubit>.value(
          value: cubit,
          child: MaterialsScreen(sharer: sharer),
        ),
      ),
    );
    await cubit.load();
    await tester.pump();
    return cubit;
  }

  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('таблица цветов схемы: артикул, название, символ, бусины, вес и итог, тема ${theme.brightness}', (
      tester,
    ) async {
      await pumpScreen(tester, theme: theme);

      expect(find.text('Материалы'), findsWidgets);
      expect(find.text('Браслет Ёлка'), findsOneWidget);
      expect(find.text('Размер бисера: Delica 11/0'), findsOneWidget);
      expect(find.text('Miyuki Delica DB0010'), findsOneWidget);
      expect(find.text('Красный'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('DMC 310 + DMC 666'), findsOneWidget);
      // В схеме 5 и 4 бусины: 0,025 г и 0,02 г — меньше десятой доли грамма.
      expect(find.text('5 шт'), findsOneWidget);
      expect(find.text('4 шт'), findsOneWidget);
      // Строки (0,025 г и 0,02 г) и итог (0,045 г) легче десятой доли грамма.
      expect(find.text('<\u00A00,1 г'), findsNWidgets(3));
      expect(find.text('Итого'), findsOneWidget);
      expect(find.text('9 шт'), findsOneWidget);
      expect(find.text('Вес примерный: у разных отделок бисер весит по-разному.'), findsOneWidget);
      expect(find.text('Поделиться списком'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('переключатель «С запасом 10%» меняет числа в таблице и итоге', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('С запасом 10%'));
    await tester.pump();

    expect(find.text('6 шт'), findsOneWidget);
    expect(find.text('11 шт'), findsOneWidget);
    expect(find.text('9 шт'), findsNothing);

    await tester.tap(find.text('По схеме'));
    await tester.pump();
    expect(find.text('9 шт'), findsOneWidget);
  });

  testWidgets('«Поделиться списком» отдаёт системному листу тот же текст, что показан на экране', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('С запасом 10%'));
    await tester.pump();

    await tester.tap(find.text('Поделиться списком'));
    await tester.pump();

    final share = sharer.shared.single;
    expect(share.subject, 'Материалы: Браслет Ёлка');
    expect(
      share.text,
      startsWith('Материалы: Браслет Ёлка\nБисер Delica 11/0\n\n1. A Miyuki Delica DB0010 Красный — 6 шт'),
    );
    expect(share.text, contains('Итого: 11 шт'));
    expect(share.text, contains('Количество указано с запасом 10%.'));
    // Источник листа на iPad и Mac — кнопка «Поделиться».
    expect(share.origin, isNotNull);
    expect(share.origin!.width, greaterThan(0));
  });

  testWidgets('ошибка системного листа показывает сообщение', (tester) async {
    sharer.fail = true;
    await pumpScreen(tester);

    await tester.tap(find.text('Поделиться списком'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось поделиться. Попробуйте ещё раз.'), findsOneWidget);
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось поделиться. Попробуйте ещё раз.'), findsNothing);
  });

  testWidgets('пустая схема: подсказка вместо таблицы, кнопки «Поделиться» нет', (tester) async {
    patterns.byProject['proj-1'] = sampleGridPattern().copyWith(grid: Grid.empty(width: 4, height: 3));
    await pumpScreen(tester);

    expect(find.text('В схеме пока нет бусин'), findsOneWidget);
    expect(find.text('Поделиться списком'), findsNothing);
  });

  testWidgets('произвольный размер ячейки: понятное объяснение без «Повторить»', (tester) async {
    patterns.byProject['proj-1'] = sampleGridPattern().copyWith(
      metrics: const CustomCellMetrics(widthMm: 2, heightMm: 3),
    );
    await pumpScreen(tester);

    expect(find.text('Не удалось посчитать материалы'), findsOneWidget);
    expect(find.textContaining('размер бусины не задан'), findsOneWidget);
    expect(find.text('Повторить'), findsNothing);
  });

  testWidgets('нет схемы: «Повторить» перечитывает', (tester) async {
    patterns.byProject.clear();
    await pumpScreen(tester);
    expect(find.text('Не удалось посчитать материалы'), findsOneWidget);

    patterns.byProject['proj-1'] = sampleGridPattern();
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Итого'), findsOneWidget);
  });

  testWidgets('строки читаются VoiceOver целиком', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpScreen(tester);

    expect(find.bySemanticsLabel(RegExp('Miyuki Delica DB0010, Красный, 5 шт')), findsOneWidget);
    handle.dispose();
  });

  for (final double scale in <double>[2, 3]) {
    testWidgets('крупный шрифт x$scale на 428 pt: без переполнения, числа под названием', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      patterns.byProject['proj-1'] = sampleGridPattern();
      await pumpScreen(tester);

      expect(find.text('Miyuki Delica DB0010'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Итого'), 200);
      expect(find.text('Итого'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('широкое окно Mac: таблица в колонке 720 pt', (tester) async {
    await pumpScreen(tester, size: const Size(1400, 900));

    expect(tester.getTopLeft(find.text('Miyuki Delica DB0010')).dx, greaterThan(300));
    expect(tester.takeException(), isNull);
  });
}
