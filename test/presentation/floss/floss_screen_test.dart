import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/materials/use_cases/load_project_floss.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/presentation/floss/floss_cubit.dart';
import 'package:beading/presentation/floss/floss_screen.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_text_sharer.dart';

Project _stitchProject() => Project(
  id: 'proj-1',
  name: 'Котик',
  status: ProjectStatus.idea,
  craft: Craft.crossStitch,
  technique: Technique.defaultFor(Craft.crossStitch),
  contentKind: ContentKind.grid,
  notes: '',
  coverPath: null,
  lastWorkedAt: DateTime.utc(2026),
);

/// 20×20: 300 крестиков красной Гаммы 3071 и 100 смесью 3071 + 3095.
GridPattern _pattern() => GridPattern(
  id: 'pat-1',
  projectId: 'proj-1',
  geometry: const RectangularGeometry(),
  metrics: Fabric.standard,
  grid: Grid.fromCells(
    width: 20,
    height: 20,
    cells: <int>[for (int i = 0; i < 400; i++) i < 300 ? 1 : 2],
  ),
  palette: PaletteSnapshot(<PatternColor>[
    PatternColor(
      rgb: const Rgb(200, 0, 0),
      name: 'Красный',
      components: const <CatalogRef>[CatalogRef(brand: 'Гамма', code: '3071')],
      symbol: 'A',
    ),
    PatternColor(
      rgb: const Rgb(100, 0, 100),
      name: 'Смесь',
      components: const <CatalogRef>[
        CatalogRef(brand: 'Гамма', code: '3071'),
        CatalogRef(brand: 'Гамма', code: '3095'),
      ],
      symbol: 'B',
    ),
  ]),
);

void main() {
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;
  late FakeTextSharer sharer;

  setUp(() {
    projects = FakeProjectRepository()..projects['proj-1'] = _stitchProject();
    patterns = FakeGridPatternRepository()..byProject['proj-1'] = _pattern();
    sharer = FakeTextSharer();
  });

  FlossCubit makeCubit() {
    final FlossCubit cubit = FlossCubit(projectId: 'proj-1', loadFloss: LoadProjectFloss(patterns), projects: projects);
    addTearDown(cubit.close);
    return cubit;
  }

  Future<void> pumpScreen(WidgetTester tester, {CupertinoThemeData theme = AppTheme.light}) async {
    tester.view
      ..physicalSize = const Size(430, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final FlossCubit cubit = makeCubit();
    await tester.pumpWidget(
      CupertinoApp(
        theme: theme,
        builder: AppTheme.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: BlocProvider<FlossCubit>.value(
          value: cubit,
          child: FlossScreen(sharer: sharer),
        ),
      ),
    );
    await cubit.load();
    await tester.pump();
  }

  group('FlossCubit', () {
    test('загружает расход: готово, имя проекта и мотки Гаммы', () async {
      final FlossCubit cubit = makeCubit();

      await cubit.load();

      expect(cubit.state.status, FlossStatus.ready);
      expect(cubit.state.projectName, 'Котик');
      expect(cubit.state.estimate!.purchases.map((p) => p.ref.brand).toSet(), <String>{'Гамма'});
      expect(cubit.state.estimate!.totalSkeins, 2);
    });

    test('нет проекта — ошибка', () async {
      projects.projects.clear();
      final FlossCubit cubit = makeCubit();

      await cubit.load();

      expect(cubit.state.status, FlossStatus.failure);
    });

    test('бисерная схема — ошибка проверки', () async {
      patterns.byProject['proj-1'] = sampleGridPattern();
      final FlossCubit cubit = makeCubit();

      await cubit.load();

      expect(cubit.state.status, FlossStatus.failure);
    });

    test('переключатель запаса меняет состояние', () async {
      final FlossCubit cubit = makeCubit();
      await cubit.load();

      cubit.setWithReserve(value: true);

      expect(cubit.state.withReserve, isTrue);
    });
  });

  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('экран: канва, список покупок по Гамме, таблица цветов и итог, тема ${theme.brightness}', (
      tester,
    ) async {
      await pumpScreen(tester, theme: theme);

      expect(find.text('Мулине'), findsWidgets);
      expect(find.text('Котик'), findsOneWidget);
      expect(find.text('Канва: Аида 14'), findsOneWidget);
      expect(find.text('Кусок канвы: 13,6 × 13,6 см (вышивка 3,6 × 3,6 см и поля по 5 см)'), findsOneWidget);
      expect(find.text('Что купить'), findsOneWidget);
      expect(find.text('Гамма 3071'), findsNWidgets(2));
      expect(find.text('Гамма 3095'), findsOneWidget);
      expect(find.text('1 моток'), findsNWidgets(4));
      expect(find.text('Гамма 3071 + Гамма 3095'), findsOneWidget);
      expect(find.text('300 крестиков'), findsOneWidget);
      expect(find.text('Итого'), findsOneWidget);
      expect(find.text('2 мотка'), findsOneWidget);
      expect(find.textContaining('Смешанная нить'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('«Поделиться» отдаёт текст со списком покупок', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Поделиться списком'));
    await tester.pump();

    final share = sharer.shared.single;
    expect(share.subject, 'Мулине: Котик');
    expect(
      share.text,
      startsWith('Мулине: Котик\nКанва Аида 14, кусок 13,6 × 13,6 см\n\n1. Гамма 3071 Красный — 1 моток'),
    );
    expect(share.text, contains('2. Гамма 3095 — 1 моток'));
    expect(share.text, contains('Итого: 2 мотка'));
    expect(share.origin, isNotNull);
  });

  testWidgets('бисерная схема: сообщение, что мулине считается только для канвы', (tester) async {
    patterns.byProject['proj-1'] = sampleGridPattern();
    await pumpScreen(tester);

    expect(find.text('Расход мулине считается только для схемы на канве.'), findsOneWidget);
  });
}
