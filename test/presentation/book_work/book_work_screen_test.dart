import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/image_pattern/book_work/page_viewport.dart';
import 'package:beading/domain/image_pattern/book_work/record_book_progress.dart';
import 'package:beading/domain/image_pattern/book_work/ruler_state.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';
import 'package:beading/domain/projects/use_cases/change_project_status.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:beading/domain/projects/use_cases/update_notes.dart';
import 'package:beading/presentation/book_work/book_work_cubit.dart';
import 'package:beading/presentation/book_work/book_work_screen.dart';
import 'package:beading/presentation/book_work/book_work_state.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:beading/presentation/widgets/row_ring.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_book_work.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_image_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/test_images.dart';

// Страницы по 100×300 px: при ширине экрана 800 они масштабируются в 8 раз, поэтому линейка уходит за экран.
const List<ImagePatternPage> _pages = <ImagePatternPage>[
  ImagePatternPage(id: 'pg-1', path: '1.png', width: 100, height: 300),
  ImagePatternPage(id: 'pg-2', path: '2.png', width: 100, height: 300),
  ImagePatternPage(id: 'pg-3', path: '3.png', width: 100, height: 300),
];

void main() {
  late FakeProjectRepository projects;
  late FakeImagePatternRepository patterns;
  late FakeBookWorkRepository work;
  late FakeFileStore files;
  late FakeClock clock;
  late String projectId;
  late Uint8List png;

  setUp(() async {
    projects = FakeProjectRepository();
    patterns = FakeImagePatternRepository();
    work = FakeBookWorkRepository();
    files = FakeFileStore();
    clock = FakeClock(DateTime.utc(2026, 11, 10, 9));
    projectId = (await CreateProject(repository: projects, ids: FakeIdGenerator(), clock: clock)(
      name: 'Колье',
    )).valueOrNull!.id;
    patterns.byProject[projectId] = ImagePattern(id: 'pat-1', projectId: projectId, pages: _pages);
    png = await redBluePng();
    for (final ImagePatternPage page in _pages) {
      files.files[page.path] = png;
    }
  });

  BookWorkCubit newCubit() => BookWorkCubit(
    projectId: projectId,
    projects: projects,
    patterns: patterns,
    work: work,
    recordProgress: RecordBookProgress(
      projects: projects,
      changeStatus: ChangeProjectStatus(repository: projects, events: BroadcastAppEvents()),
      touch: TouchProject(repository: projects, clock: clock),
    ),
    updateNotes: UpdateNotes(projects),
    saveDelay: const Duration(milliseconds: 50),
  );

  Widget app(BookWorkCubit cubit, CupertinoThemeData theme) => CupertinoApp(
    theme: theme,
    builder: AppTheme.builder,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<BookWorkCubit>.value(
      value: cubit,
      child: BookWorkScreen(files: files),
    ),
  );

  Future<BookWorkCubit> open(WidgetTester tester, {CupertinoThemeData? theme}) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final BookWorkCubit cubit = newCubit();
    await tester.pumpWidget(app(cubit, theme ?? AppTheme.light));
    await cubit.load();
    await tester.pump();
    await tester.pump();
    return cubit;
  }

  /// Номер ряда в панели плетения (метка у линейки показывает тот же номер).
  Finder counter(String text) =>
      find.descendant(of: find.byKey(const ValueKey<String>('row-swipe-area')), matching: find.text(text));

  /// Выгружает экран и дожидается записи, как при закрытии экрана.
  Future<void> closeScreen(WidgetTester tester, BookWorkCubit cubit) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(cubit.close);
  }

  testWidgets('главный вид: имя работы, ряд 1, кнопки, зум до 8×', (tester) async {
    final BookWorkCubit cubit = await open(tester);

    expect(counter('Ряд 1'), findsOneWidget);
    expect(find.text('Ряд назад'), findsOneWidget);
    expect(find.text('Следующий ряд'), findsOneWidget);
    expect(find.text('Страница 1 из 3'), findsOneWidget);
    expect(tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).maxScale, 8);
    expect(find.byKey(const ValueKey<String>('ruler-band')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey<String>('ruler-band')), matching: find.byType(RowRing)),
      findsOneWidget,
    );
    await closeScreen(tester, cubit);
  });

  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('кнопки ряда крупные, не меньше 56 pt, в теме ${theme.brightness}', (tester) async {
      final BookWorkCubit cubit = await open(tester, theme: theme);

      for (final String key in <String>['previous-row', 'next-row']) {
        final Size size = tester.getSize(find.byKey(ValueKey<String>(key)));
        expect(size.height, greaterThanOrEqualTo(56));
        expect(size.width, greaterThanOrEqualTo(56));
      }
      await closeScreen(tester, cubit);
    });
  }

  testWidgets('кнопки сдвигают линейку; назад у верха недоступна', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    expect(tester.widget<CupertinoButton>(find.byKey(const ValueKey<String>('previous-row'))).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey<String>('next-row')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('next-row')));
    await tester.pump();
    expect(counter('Ряд 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('previous-row')));
    await tester.pump();
    expect(counter('Ряд 2'), findsOneWidget);
    await closeScreen(tester, cubit);
  });

  testWidgets('после пересоздания экрана позиция линейки та же', (tester) async {
    final BookWorkCubit first = await open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('next-row')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('next-row')));
    await tester.pump();
    final double top = first.state.work.ruler.top;
    await closeScreen(tester, first);

    final BookWorkCubit second = await open(tester);

    expect(counter('Ряд 3'), findsOneWidget);
    expect(second.state.work.ruler.top, top);
    await closeScreen(tester, second);
  });

  testWidgets('свайп вверх по номеру ряда — следующий ряд, вниз — назад', (tester) async {
    final BookWorkCubit cubit = await open(tester);

    await tester.fling(find.byKey(const ValueKey<String>('row-swipe-area')), const Offset(0, -80), 1000);
    await tester.pump();
    expect(counter('Ряд 2'), findsOneWidget);

    await tester.fling(find.byKey(const ValueKey<String>('row-swipe-area')), const Offset(0, 80), 1000);
    await tester.pump();
    expect(counter('Ряд 1'), findsOneWidget);
    await closeScreen(tester, cubit);
  });

  testWidgets('стрелки клавиатуры двигают линейку (macOS)', (tester) async {
    final BookWorkCubit cubit = await open(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(counter('Ряд 2'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(counter('Ряд 1'), findsOneWidget);
    await closeScreen(tester, cubit);
  });

  testWidgets('переключение страниц на трёхстраничной схеме, у каждой своя линейка', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('next-row')));
    await tester.pump();

    await tester.tap(find.text('Страница 1 из 3'));
    await tester.pumpAndSettle();
    expect(find.text('Страница 1'), findsOneWidget);
    expect(find.text('Страница 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('page-item-1')));
    await tester.pumpAndSettle();

    expect(find.text('Страница 2 из 3'), findsOneWidget);
    expect(counter('Ряд 1'), findsOneWidget);
    expect(cubit.state.pageIndex, 1);

    await tester.tap(find.text('Страница 2 из 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('page-item-0')));
    await tester.pumpAndSettle();
    expect(counter('Ряд 2'), findsOneWidget);
    await closeScreen(tester, cubit);
  });

  testWidgets('в списке страниц у страницы с пометками есть значок маркера', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    cubit
      ..startMarker()
      ..addStroke(<double>[0.1, 0.1, 0.2, 0.2])
      ..finishMarker();
    await tester.pump();

    await tester.tap(find.text('Страница 1 из 3'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('page-marked-0')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('page-marked-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('page-item-0')));
    await tester.pumpAndSettle();
    await closeScreen(tester, cubit);
  });

  testWidgets('открытая страница запоминается и открывается снова', (tester) async {
    final BookWorkCubit first = await open(tester);
    await tester.tap(find.text('Страница 1 из 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('page-item-2')));
    await tester.pumpAndSettle();
    await closeScreen(tester, first);

    final BookWorkCubit second = await open(tester);

    expect(find.text('Страница 3 из 3'), findsOneWidget);
    await closeScreen(tester, second);
  });

  testWidgets('у одностраничной схемы кнопки выбора страницы нет', (tester) async {
    patterns.byProject[projectId] = ImagePattern(
      id: 'pat-1',
      projectId: projectId,
      pages: <ImagePatternPage>[_pages.first],
    );

    final BookWorkCubit cubit = await open(tester);

    expect(find.textContaining('Страница '), findsNothing);
    await closeScreen(tester, cubit);
  });

  testWidgets('настройка линейки: цвет, высота и шаг', (tester) async {
    final BookWorkCubit cubit = await open(tester);

    await tester.tap(find.bySemanticsLabel('Настройка линейки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('ruler-color-blue')));
    await tester.pump();
    expect(cubit.state.work.ruler.highlight, RulerHighlight.blue);

    // Cupertino-ползунок ловит касание только на «бегунке», поэтому значение задаём его обработчиком.
    final CupertinoSlider heightSlider = tester.widget(find.byKey(const ValueKey<String>('ruler-height-slider')));
    heightSlider.onChanged!(30);
    await tester.pump();
    expect(cubit.state.work.ruler.height, 30);

    final CupertinoSlider stepSlider = tester.widget(find.byKey(const ValueKey<String>('ruler-step-slider')));
    stepSlider.onChanged!(12);
    await tester.pump();
    expect(cubit.state.work.ruler.step, 12);

    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(find.text('Высота линейки'), findsNothing);
    await closeScreen(tester, cubit);
  });

  testWidgets('заметки открываются нижним листом и сохраняются в проект', (tester) async {
    final BookWorkCubit cubit = await open(tester);

    await tester.tap(find.bySemanticsLabel('Заметки'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey<String>('notes-field')), 'после ряда 12 — синий');
    await tester.pump();
    expect(cubit.state.notes, 'после ряда 12 — синий');

    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    await closeScreen(tester, cubit);
    expect(projects.projects[projectId]!.notes, 'после ряда 12 — синий');
  });

  testWidgets('линейка ушла за экран — вид следует за ней, запоминается вместе с линейкой', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    final PageViewport before = cubit.state.work.viewport;

    cubit.setRulerStep(150);
    cubit.nextRow();
    await tester.pump();
    await tester.pump();

    final PageViewport after = cubit.state.work.viewport;
    expect(after.dy, lessThan(before.dy));
    // Линейка в экранных координатах (страница 100 px → 800 px, ×8) попадает в окно между панелями.
    final double screenTop = after.scale * cubit.state.work.ruler.top * 8 + after.dy;
    expect(screenTop, inInclusiveRange(60, 1000 - 160));
    await closeScreen(tester, cubit);
    expect(work.pages['pg-1']!.viewport, after);
  });

  testWidgets('схема не открылась — сообщение и кнопка закрытия', (tester) async {
    patterns.byProject.clear();

    final BookWorkCubit cubit = await open(tester);

    expect(cubit.state.status, BookWorkStatus.failed);
    expect(find.text('Схема не открылась. Закрой экран и попробуй ещё раз.'), findsOneWidget);
    expect(find.text('Закрыть'), findsOneWidget);
    await closeScreen(tester, cubit);
  });

  testWidgets('нет файла картинки — подсказка вместо страницы', (tester) async {
    files.files.clear();

    final BookWorkCubit cubit = await open(tester);

    expect(find.text('Не получилось показать эту страницу. Попробуй открыть её ещё раз.'), findsOneWidget);
    await closeScreen(tester, cubit);
  });

  testWidgets('метка «Ряд» и ручка высоты лежат вне полосы линейки', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('next-row')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('next-row')));
    await tester.pump();

    final Rect band = tester.getRect(find.byKey(const ValueKey<String>('ruler-band')));
    final Rect ear = tester.getRect(find.byKey(const ValueKey<String>('ruler-ear')));
    final Rect handle = tester.getRect(find.byKey(const ValueKey<String>('ruler-handle')));
    expect(ear.bottom, lessThanOrEqualTo(band.top + 0.5));
    expect(handle.top + (handle.height - 30) / 2, greaterThanOrEqualTo(band.bottom - 0.5));
    expect(handle.height, greaterThanOrEqualTo(44));
    await closeScreen(tester, cubit);
  });

  testWidgets('ручка растит линейку', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    final double before = cubit.state.work.ruler.height;

    await tester.drag(find.byKey(const ValueKey<String>('ruler-handle')), const Offset(0, 40));
    await tester.pump();

    expect(cubit.state.work.ruler.height, greaterThan(before));
    await closeScreen(tester, cubit);
  });

  testWidgets('снизу вверх: притушено под линейкой, ухо и ручка меняются местами', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    cubit.setDirection(RowDirection.bottomUp);
    await tester.pump();
    await tester.pump();

    final Rect band = tester.getRect(find.byKey(const ValueKey<String>('ruler-band')));
    final Rect dim = tester.getRect(find.byKey(const ValueKey<String>('ruler-dim')));
    expect(dim.top, closeTo(band.bottom, 0.5));
    final Rect ear = tester.getRect(find.byKey(const ValueKey<String>('ruler-ear')));
    final Rect handle = tester.getRect(find.byKey(const ValueKey<String>('ruler-handle')));
    expect(ear.top, greaterThan(handle.top));
    expect(
      tester.widget<CupertinoButton>(find.byKey(const ValueKey<String>('next-row'))).onPressed,
      isNotNull,
    );
    await closeScreen(tester, cubit);
  });

  testWidgets('после сдвига появляется «Отменить», по нажатию линейка возвращается', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('next-row')));
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('undo-row')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('undo-row')));
    await tester.pump();

    expect(cubit.state.work.ruler.row, 1);
    expect(find.byKey(const ValueKey<String>('undo-row')), findsNothing);
    await closeScreen(tester, cubit);
  });

  testWidgets('тост «Отменить» сам исчезает через несколько секунд', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('next-row')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));

    expect(find.byKey(const ValueKey<String>('undo-row')), findsNothing);
    await closeScreen(tester, cubit);
  });

  testWidgets('последний ряд: баннер и кнопка «Следующая страница» открывает следующую', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    cubit.setRulerStep(5000);
    cubit.nextRow();
    cubit.nextRow();
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));

    expect(find.byKey(const ValueKey<String>('page-end-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('next-row')), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('next-page')));
    await tester.pump();

    expect(cubit.state.pageIndex, 1);
    await closeScreen(tester, cubit);
  });

  testWidgets('панель сворачивается в капсулу и разворачивается', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    final double full = tester.getSize(find.byKey(const ValueKey<String>('toggle-panel'))).height;
    expect(find.byKey(const ValueKey<String>('previous-row')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('toggle-panel')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('previous-row')), findsNothing);
    expect(find.byKey(const ValueKey<String>('next-row')), findsOneWidget);
    expect(counter('Ряд 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('toggle-panel')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('previous-row')), findsOneWidget);
    expect(full, greaterThanOrEqualTo(44));
    await closeScreen(tester, cubit);
  });

  testWidgets('индикатор масштаба и отдельная «По ширине» возвращает масштаб 1', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    expect(find.byKey(const ValueKey<String>('zoom-level')), findsOneWidget);
    final InteractiveViewer viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    viewer.transformationController!.value = Matrix4.identity()..scaleByDouble(3, 3, 1, 1);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Масштаб ×3,0'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('fit-width')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Масштаб ×1,0'), findsOneWidget);
    expect(cubit.state.work.viewport.scale, 1);
    await closeScreen(tester, cubit);
  });

  testWidgets('на только что открытой странице ухо над полосой, а не на ней', (tester) async {
    final BookWorkCubit cubit = await open(tester);

    final Rect band = tester.getRect(find.byKey(const ValueKey<String>('ruler-band')));
    final Rect ear = tester.getRect(find.byKey(const ValueKey<String>('ruler-ear')));
    expect(ear.bottom, lessThanOrEqualTo(band.top + 0.5));

    cubit.setDirection(RowDirection.bottomUp);
    await tester.pump();
    await tester.pump();
    final Rect bandUp = tester.getRect(find.byKey(const ValueKey<String>('ruler-band')));
    final Rect earUp = tester.getRect(find.byKey(const ValueKey<String>('ruler-ear')));
    expect(earUp.top, greaterThanOrEqualTo(bandUp.bottom - 0.5));
    await closeScreen(tester, cubit);
  });

  testWidgets('снизу вверх: ручка над полосой тянет вверх, стрелка вверх — следующий ряд', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    cubit.setDirection(RowDirection.bottomUp);
    await tester.pump();
    await tester.pump();
    final double before = cubit.state.work.ruler.height;
    final double bottom = cubit.state.work.ruler.bottom;

    await tester.drag(find.byKey(const ValueKey<String>('ruler-handle')), const Offset(0, -20));
    await tester.pump();
    expect(cubit.state.work.ruler.height, greaterThan(before));
    expect(cubit.state.work.ruler.bottom, closeTo(bottom, 1e-6));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(cubit.state.work.ruler.row, 2);
    await closeScreen(tester, cubit);
  });

  testWidgets('в листе линейки есть переключатель направления', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    await tester.tap(find.bySemanticsLabel('Настройка линейки'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Снизу вверх'));
    await tester.pumpAndSettle();

    expect(cubit.state.work.ruler.direction, RowDirection.bottomUp);
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    await closeScreen(tester, cubit);
  });

  testWidgets('границы схемы: кнопка включает ручки, ручка двигает край, «Готово» их убирает', (tester) async {
    final BookWorkCubit cubit = await open(tester);

    await tester.tap(find.byKey(const ValueKey<String>('edit-zone')));
    await tester.pump();
    expect(cubit.state.zoneEditing, isTrue);
    expect(find.byKey(const ValueKey<String>('zone-frame')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('ruler-handle')), findsNothing);

    await tester.drag(find.byKey(const ValueKey<String>('zone-handle-top')), const Offset(0, 60));
    await tester.pump();
    expect(cubit.state.work.ruler.zone!.top, greaterThan(0));
    // Первый ряд встаёт к новому верху схемы.
    expect(cubit.state.work.ruler.top, cubit.state.work.ruler.zone!.top);

    await tester.drag(find.byKey(const ValueKey<String>('zone-handle-left')), const Offset(40, 0));
    await tester.pump();
    expect(cubit.state.work.ruler.zone!.left, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey<String>('zone-done')));
    await tester.pump();
    expect(cubit.state.zoneEditing, isFalse);
    expect(find.byKey(const ValueKey<String>('zone-frame')), findsNothing);
    expect(cubit.state.work.ruler.zone, isNotNull);
    await closeScreen(tester, cubit);
  });

  testWidgets('маркер: палец рисует мазок, «Готово» возвращает линейку', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('start-marker')));
    await tester.pump();
    expect(cubit.state.markerEditing, isTrue);
    expect(find.byKey(const ValueKey<String>('ruler-handle')), findsNothing);

    final TestGesture finger = await tester.startGesture(const Offset(400, 500));
    await finger.moveBy(const Offset(40, 10));
    await finger.moveBy(const Offset(40, 10));
    await finger.up();
    await tester.pump();
    expect(cubit.state.work.markup.strokes, hasLength(1));
    expect(cubit.state.canUndoMarkup, isTrue);

    await tester.tap(find.byKey(const ValueKey<String>('marker-done')));
    await tester.pump();
    expect(cubit.state.markerEditing, isFalse);
    expect(cubit.state.work.markup.strokes, hasLength(1));
    await closeScreen(tester, cubit);
  });

  testWidgets('«Вся страница» в режиме границ снимает зону', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('edit-zone')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('zone-reset')));
    await tester.pump();

    expect(cubit.state.zoneEditing, isFalse);
    expect(cubit.state.work.ruler.zone, isNull);
    await closeScreen(tester, cubit);
  });

  testWidgets('лист линейки: число рядов в зоне задаёт высоту и шаг', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    await tester.tap(find.bySemanticsLabel('Настройка линейки'));
    await tester.pumpAndSettle();
    expect(find.text('Рядов в схеме'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('row-count-more')));
    await tester.pump();
    final int first = cubit.state.work.ruler.rowCount!;
    expect(first, greaterThan(0));
    expect(cubit.state.work.ruler.height, closeTo(300 / first, 1e-6));

    await tester.tap(find.byKey(const ValueKey<String>('row-count-more')));
    await tester.pump();
    expect(cubit.state.work.ruler.rowCount, first + 1);

    await tester.tap(find.byKey(const ValueKey<String>('row-count-manual')));
    await tester.pump();
    expect(cubit.state.work.ruler.rowCount, isNull);

    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    await closeScreen(tester, cubit);
  });

  testWidgets('лист линейки: «Обвести схему на фото» закрывает лист и включает ручки', (tester) async {
    final BookWorkCubit cubit = await open(tester);
    await tester.tap(find.bySemanticsLabel('Настройка линейки'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('zone-edit')));
    await tester.pumpAndSettle();

    expect(cubit.state.zoneEditing, isTrue);
    expect(find.text('Рядов в схеме'), findsNothing);
    await closeScreen(tester, cubit);
  });
}
