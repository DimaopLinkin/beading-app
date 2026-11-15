import 'package:beading/core/failure.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/image_pattern/pdf_rasterizer.dart';
import 'package:beading/domain/materials/use_cases/load_project_floss.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/printing/print_options.dart';
import 'package:beading/domain/printing/print_options_store.dart';
import 'package:beading/domain/printing/use_cases/export_pattern_pdf.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/presentation/floss/floss_cubit.dart';
import 'package:beading/presentation/floss/floss_screen.dart';
import 'package:beading/presentation/grid_pattern/stitch_legend_view.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_biser.dart';
import '../../support/fake_floss_stock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_image_pattern.dart';
import '../../support/fake_pattern_printer.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_settings_repository.dart';
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
  late FakeFileSharer fileSharer;
  late FakePatternPrinter printer;
  late FakeSettingsRepository settings;
  late FakeFlossStockRepository stock;
  late FakeCellProgressStore progress;

  setUp(() {
    projects = FakeProjectRepository()..projects['proj-1'] = _stitchProject();
    patterns = FakeGridPatternRepository()..byProject['proj-1'] = _pattern();
    sharer = FakeTextSharer();
    fileSharer = FakeFileSharer();
    printer = FakePatternPrinter();
    settings = FakeSettingsRepository();
    stock = FakeFlossStockRepository();
    progress = FakeCellProgressStore(width: 20);
  });

  FlossCubit makeCubit() {
    final FlossCubit cubit = FlossCubit(
      projectId: 'proj-1',
      loadFloss: LoadProjectFloss(patterns, progress: progress),
      exportPdf: ExportPatternPdf(projects: projects, patterns: patterns, printer: printer),
      printOptions: PrintOptionsStore(settings),
      projects: projects,
      stock: stock,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    CupertinoThemeData theme = AppTheme.light,
    PdfRasterizer? rasterizer,
  }) async {
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
          child: FlossScreen(sharer: sharer, fileSharer: fileSharer, rasterizer: rasterizer),
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

    test('запас: без запаса докупить всё, с запасом — только недостающее', () async {
      final FlossCubit cubit = makeCubit();
      await cubit.load();

      expect(cubit.state.shortage!.totalToBuy, 2);

      await cubit.setStock(const CatalogRef(brand: 'Гамма', code: '3071'), 5);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.stock.single.skeins, 5);
      expect(cubit.state.shortage!.lines.first.toBuy, 0);
      expect(cubit.state.shortage!.totalToBuy, 1);
    });

    test('ошибка записи запаса попадает в состояние и сбрасывается следующей записью', () async {
      final FlossCubit cubit = makeCubit();
      await cubit.load();
      stock.failNextWrite = const StorageFailure('boom');

      await cubit.setStock(const CatalogRef(brand: 'Гамма', code: '3071'), 1);
      expect(cubit.state.writeFailure, isA<StorageFailure>());

      await cubit.setStock(const CatalogRef(brand: 'Гамма', code: '3071'), 1);
      expect(cubit.state.writeFailure, isNull);
    });

    test('«осталось вышить» пересчитывает расход по невышитым клеткам и сохраняет запас', () async {
      await progress.setCells(
        'pat-1',
        <CellPosition>[for (int i = 0; i < 300; i++) CellPosition(i % 20, i ~/ 20)],
        done: true,
      );
      final FlossCubit cubit = makeCubit();
      await cubit.load();
      await cubit.setStock(const CatalogRef(brand: 'Гамма', code: '3095'), 1);
      await Future<void>.delayed(Duration.zero);

      await cubit.setRemainingOnly(value: true);

      expect(cubit.state.remainingOnly, isTrue);
      expect(cubit.state.estimate!.totalCrossStitches, 100);
      expect(cubit.state.stock, isNotEmpty);
      expect(cubit.state.status, FlossStatus.ready);
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

  testWidgets(
    'печать: лист настроек показывает страницы, формат и места запоминаются, PDF уходит в «Поделиться» (T76, T80)',
    (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Распечатать схему (PDF)'));
      await tester.pumpAndSettle();
      expect(find.text('Печать схемы'), findsOneWidget);
      expect(find.textContaining('Страниц: 2 (схема 1 + легенда 1)'), findsOneWidget);

      await tester.tap(find.text('A3'));
      await tester.tap(find.byKey(const ValueKey<String>('print-slots-minus')));
      await tester.pumpAndSettle();
      expect(find.text('45'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('print-build')));
      await tester.pumpAndSettle();

      expect(printer.calls.single.title, 'Котик');
      expect(printer.calls.single.options, const PrintOptions(paper: PrintPaper.a3, slotsPerRack: 45));
      final share = fileSharer.shared.single;
      expect(share.fileName, 'Котик.pdf');
      expect(share.origin, isNotNull);
      expect(await PrintOptionsStore(settings).load(), const PrintOptions(paper: PrintPaper.a3, slotsPerRack: 45));

      // Следующая печать начинается с запомненных настроек.
      await tester.tap(find.text('Распечатать схему (PDF)'));
      await tester.pumpAndSettle();
      expect(find.text('45'), findsOneWidget);
    },
  );

  testWidgets('окно «Нитки»: номер места и образец с символом; места берутся из настройки вышивки (T83)', (
    tester,
  ) async {
    await PrintOptionsStore(settings).save(const PrintOptions(slotsPerRack: 80), projectId: 'proj-1');
    await pumpScreen(tester);

    final Finder first = find.byKey(const ValueKey<String>('floss-color-slot-1'), skipOffstage: false);
    expect(tester.widget<Text>(first).data, '1');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey<String>('floss-color-slot-2'), skipOffstage: false)).data,
      '2',
    );
    expect(find.byType(LegendSwatch, skipOffstage: false), findsWidgets);
    final FlossCubit cubit = tester.element(find.byType(FlossScreen)).read<FlossCubit>();
    expect(cubit.state.printOptions.slotsPerRack, 80);
  });

  testWidgets('просмотр PDF: сначала страницы, «Поделиться» из просмотра отдаёт файл (T81)', (tester) async {
    final FakePdfRasterizer rasterizer = FakePdfRasterizer()..pages = 3;
    await pumpScreen(tester, rasterizer: rasterizer);

    await tester.tap(find.text('Распечатать схему (PDF)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('print-build')));
    await tester.pumpAndSettle();

    expect(find.text('Страница 1 из 3'), findsOneWidget);
    expect(fileSharer.shared, isEmpty, reason: 'сначала просмотр');
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Страница 2 из 3'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.share));
    await tester.pumpAndSettle();
    expect(fileSharer.shared.single.fileName, 'Котик.pdf');
    expect(fileSharer.shared.single.origin, isNotNull);
  });

  testWidgets('ошибка сборки PDF: понятное сообщение, файл не отдаётся (T76)', (tester) async {
    printer.failure = const UnexpectedFailure('boom');
    await pumpScreen(tester);

    await tester.tap(find.text('Распечатать схему (PDF)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('print-build')));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось собрать PDF. Попробуйте ещё раз.'), findsOneWidget);
    expect(fileSharer.shared, isEmpty);
  });

  testWidgets('отмена в листе настроек ничего не собирает', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Распечатать схему (PDF)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(printer.calls, isEmpty);
    expect(fileSharer.shared, isEmpty);
  });

  testWidgets('бисерная схема: сообщение, что мулине считается только для канвы', (tester) async {
    patterns.byProject['proj-1'] = sampleGridPattern();
    await pumpScreen(tester);

    expect(find.text('Расход мулине считается только для схемы на канве.'), findsOneWidget);
  });

  testWidgets('строка нитки: нужно / есть / докупить, итог сверки', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Докупить: 2 мотка'), findsOneWidget);
    expect(find.textContaining('Нужно '), findsNWidgets(2));
    expect(find.text('Докупить: 1 моток'), findsNWidgets(2));
  });

  testWidgets('нажатие на нитку открывает лист запаса; сохранение меняет «хватает»', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Гамма 3095'));
    await tester.pumpAndSettle();
    expect(find.text('Запас: Гамма 3095'), findsOneWidget);

    for (int i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey<String>('stock-more')));
      await tester.pump();
    }
    expect(find.text('2 мот.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('stock-save')));
    await tester.pumpAndSettle();

    expect(find.text('Хватает'), findsOneWidget);
    expect(stock.snapshot[const CatalogRef(brand: 'Гамма', code: '3095')], 2);
  });

  testWidgets('«Нет в запасе» убирает нитку', (tester) async {
    stock = FakeFlossStockRepository(
      initial: <CatalogRef, double>{const CatalogRef(brand: 'Гамма', code: '3095'): 3},
    );
    await pumpScreen(tester);

    await tester.tap(find.text('Гамма 3095'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('stock-clear')));
    await tester.pumpAndSettle();

    expect(stock.snapshot, isEmpty);
  });

  testWidgets('«Поделиться» добавляет блок «Докупить», если запас заведён', (tester) async {
    stock = FakeFlossStockRepository(
      initial: <CatalogRef, double>{const CatalogRef(brand: 'Гамма', code: '3071'): 5},
    );
    await pumpScreen(tester);

    await tester.tap(find.text('Поделиться списком'));
    await tester.pump();

    expect(sharer.shared.single.text, contains('Докупить:\n1. Гамма 3095 — 1 моток'));
  });

  testWidgets('«Осталось вышить»: переключатель и пустой остаток, когда всё вышито', (tester) async {
    await progress.setCells(
      'pat-1',
      <CellPosition>[for (int i = 0; i < 400; i++) CellPosition(i % 20, i ~/ 20)],
      done: true,
    );
    await pumpScreen(tester);

    await tester.tap(find.text('Осталось вышить'));
    await tester.pumpAndSettle();

    expect(find.text('Все крестики вышиты'), findsOneWidget);
    expect(find.text('Вся схема'), findsOneWidget);
  });
}
