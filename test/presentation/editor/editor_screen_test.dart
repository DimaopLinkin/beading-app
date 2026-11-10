import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/use_cases/save_grid_pattern.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:beading/presentation/editor/editor_canvas.dart';
import 'package:beading/presentation/editor/editor_cubit.dart';
import 'package:beading/presentation/editor/editor_screen.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';

void main() {
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;
  late EditorCubit cubit;

  Future<void> pumpEditor(
    WidgetTester tester, {
    CupertinoThemeData? theme,
    Size size = const Size(390, 844),
    int width = 8,
    int height = 8,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    projects = FakeProjectRepository();
    patterns = FakeGridPatternRepository();
    projects.projects['p'] = Project(
      id: 'p',
      name: 'Браслет',
      status: ProjectStatus.idea,
      craft: Craft.beading,
      technique: Technique.loom,
      contentKind: ContentKind.grid,
      notes: '',
      coverPath: null,
      lastWorkedAt: DateTime.utc(2026),
    );
    patterns.byProject['p'] = GridPattern(
      id: 'pat',
      projectId: 'p',
      geometry: const GridGeometry.rectangular(),
      metrics: BeadSize.delica11,
      grid: Grid.empty(width: width, height: height),
      palette: samplePalette(),
    );
    cubit = EditorCubit(
      projectId: 'p',
      projects: projects,
      patterns: patterns,
      savePattern: SaveGridPattern(patterns),
      touchProject: TouchProject(repository: projects, clock: FakeClock(DateTime.utc(2026, 2))),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      CupertinoApp(
        theme: theme ?? AppTheme.light,
        builder: AppTheme.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<EditorCubit>.value(
          value: cubit,
          child: EditorScreen(catalog: FakeCatalogRepository()),
        ),
      ),
    );
    await cubit.load();
    await tester.pumpAndSettle();
  }

  Grid grid() => cubit.state.pattern!.grid;

  Future<void> finish(WidgetTester tester) async {
    await cubit.close();
    await tester.pump();
  }

  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('экран готов в теме ${theme.brightness}: полотно, инструменты, палитра', (tester) async {
      await pumpEditor(tester, theme: theme);
      expect(find.text('Браслет'), findsOneWidget);
      expect(find.byType(EditorCanvas), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('tool-brush')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('editor-palette')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('swatch-1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('palette-add')), findsOneWidget);
      await finish(tester);
    });
  }

  testWidgets('касание полотна кистью красит ячейку', (tester) async {
    await pumpEditor(tester);

    await tester.tapAt(tester.getCenter(find.byType(EditorCanvas)));
    await tester.pump();

    expect(grid().cells.where((v) => v == 1), hasLength(1));
    await finish(tester);
  });

  testWidgets('протяжка пальцем слева направо не оставляет пропусков', (tester) async {
    await pumpEditor(tester, width: 30, height: 4);
    final Rect box = tester.getRect(find.byType(EditorCanvas));
    final double y = box.top + 6;

    final TestGesture gesture = await tester.startGesture(Offset(box.left + 5, y));
    // Скачки по 60 px: больше ширины ячейки, пропущенное дорисовывает отрезок.
    for (double x = box.left + 65; x < box.right - 5; x += 60) {
      await gesture.moveTo(Offset(x, y));
    }
    await gesture.up();
    await tester.pump();

    final List<int> painted = <int>[
      for (int c = 0; c < grid().width; c++)
        if (grid().at(c, 0) == 1) c,
    ];
    expect(painted, isNotEmpty);
    expect(painted.last - painted.first + 1, painted.length, reason: 'в мазке есть дыры: $painted');
    await finish(tester);
  });

  testWidgets('два пальца (зум) не оставляют точку и не запускают заливку', (tester) async {
    await pumpEditor(tester);
    final Offset center = tester.getCenter(find.byType(EditorCanvas));

    final TestGesture a = await tester.startGesture(center - const Offset(20, 0), pointer: 1);
    final TestGesture b = await tester.startGesture(center + const Offset(20, 0), pointer: 2);
    await a.moveTo(center - const Offset(60, 0));
    await b.moveTo(center + const Offset(60, 0));
    await a.up();
    await b.up();
    await tester.pump();
    expect(grid().cells.every((v) => v == 0), isTrue);
    expect(cubit.state.canUndo, isFalse);

    await tester.ensureVisible(find.byKey(const ValueKey<String>('tool-fill')));
    await tester.tap(find.byKey(const ValueKey<String>('tool-fill')));
    await tester.pump();
    final TestGesture c = await tester.startGesture(center - const Offset(20, 0), pointer: 3);
    final TestGesture d = await tester.startGesture(center + const Offset(20, 0), pointer: 4);
    await c.moveTo(center - const Offset(60, 0));
    await d.moveTo(center + const Offset(60, 0));
    await c.up();
    await d.up();
    await tester.pump();
    expect(grid().cells.every((v) => v == 0), isTrue);
    await finish(tester);
  });

  testWidgets('отмена и повтор мазка кнопками', (tester) async {
    await pumpEditor(tester);
    await tester.tapAt(tester.getCenter(find.byType(EditorCanvas)));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('editor-undo')));
    await tester.pump();
    expect(grid().cells.every((v) => v == 0), isTrue);

    await tester.tap(find.byKey(const ValueKey<String>('editor-redo')));
    await tester.pump();
    expect(grid().cells.where((v) => v == 1), hasLength(1));
    await finish(tester);
  });

  testWidgets('выбор цвета в палитре меняет цвет кисти', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byKey(const ValueKey<String>('swatch-2')));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(EditorCanvas)));
    await tester.pump();

    expect(grid().cells.where((v) => v == 2), hasLength(1));
    await finish(tester);
  });

  testWidgets('новый цвет из каталога появляется в палитре и становится текущим', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byKey(const ValueKey<String>('palette-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey<String>('cat-${FakeCatalogRepository.blue.id}')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('color-done')));
    await tester.pumpAndSettle();

    expect(cubit.state.pattern!.palette.length, 3);
    expect(cubit.state.pattern!.palette.colorAt(3)!.name, 'Синий');
    expect(cubit.state.activeColor, 3);
    await finish(tester);
  });

  testWidgets('поиск по артикулу в листе цвета', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.byKey(const ValueKey<String>('palette-add')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey<String>('color-search')), 'db0002');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.byKey(ValueKey<String>('cat-${FakeCatalogRepository.blue.id}')), findsOneWidget);
    expect(find.byKey(ValueKey<String>('cat-${FakeCatalogRepository.red.id}')), findsNothing);
    await finish(tester);
  });

  testWidgets('удаление цвета через лист цвета', (tester) async {
    await pumpEditor(tester);

    await tester.longPress(find.byKey(const ValueKey<String>('swatch-2')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey<String>('color-delete')));
    await tester.tap(find.byKey(const ValueKey<String>('color-delete')));
    await tester.pumpAndSettle();

    expect(cubit.state.pattern!.palette.length, 1);
    await finish(tester);
  });

  testWidgets('зеркало из меню зеркалит схему', (tester) async {
    await pumpEditor(tester);
    await tester.tapAt(tester.getCenter(find.byType(EditorCanvas)));
    await tester.pump();
    final int before = grid().cells.indexWhere((v) => v == 1);

    await tester.ensureVisible(find.byKey(const ValueKey<String>('tool-mirror')));
    await tester.tap(find.byKey(const ValueKey<String>('tool-mirror')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('mirror-h')));
    await tester.pumpAndSettle();

    final int after = grid().cells.indexWhere((v) => v == 1);
    expect(after % 8, 7 - before % 8);
    await finish(tester);
  });

  testWidgets('вставка ряда из меню рядов и столбцов', (tester) async {
    await pumpEditor(tester);
    await tester.tapAt(tester.getCenter(find.byType(EditorCanvas)));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const ValueKey<String>('tool-rows')));
    await tester.tap(find.byKey(const ValueKey<String>('tool-rows')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('row-below')));
    await tester.pumpAndSettle();

    expect(grid().height, 9);
    await finish(tester);
  });

  testWidgets('широкое окно: палитра сбоку', (tester) async {
    await pumpEditor(tester, size: const Size(1100, 800));

    expect(find.byKey(const ValueKey<String>('editor-palette')), findsNothing);
    final Offset swatch = tester.getCenter(find.byKey(const ValueKey<String>('swatch-1')));
    expect(swatch.dx, greaterThan(800));
    await finish(tester);
  });

  testWidgets('символы показываются на кружках палитры', (tester) async {
    await pumpEditor(tester);
    expect(find.text('A'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey<String>('tool-symbols')));
    await tester.tap(find.byKey(const ValueKey<String>('tool-symbols')));
    await tester.pump();

    expect(find.text('A'), findsWidgets);
    await finish(tester);
  });
}
