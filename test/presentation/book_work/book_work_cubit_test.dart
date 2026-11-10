import 'dart:async';

import 'package:beading/core/failure.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/image_pattern/book_work/page_viewport.dart';
import 'package:beading/domain/image_pattern/book_work/page_work.dart';
import 'package:beading/domain/image_pattern/book_work/record_book_progress.dart';
import 'package:beading/domain/image_pattern/book_work/ruler_state.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/change_project_status.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:beading/domain/projects/use_cases/update_notes.dart';
import 'package:beading/presentation/book_work/book_work_cubit.dart';
import 'package:beading/presentation/book_work/book_work_state.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_book_work.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_image_pattern.dart';
import '../../support/fake_project_repository.dart';

const List<ImagePatternPage> _pages = <ImagePatternPage>[
  ImagePatternPage(id: 'pg-1', path: '1.png', width: 100, height: 1000),
  ImagePatternPage(id: 'pg-2', path: '2.png', width: 100, height: 500),
  ImagePatternPage(id: 'pg-3', path: '3.png', width: 100, height: 800),
];

void main() {
  late FakeProjectRepository projects;
  late FakeImagePatternRepository patterns;
  late FakeBookWorkRepository work;
  late FakeClock clock;
  late String projectId;

  setUp(() async {
    projects = FakeProjectRepository();
    patterns = FakeImagePatternRepository();
    work = FakeBookWorkRepository();
    clock = FakeClock(DateTime.utc(2026, 11, 10, 9));
    projectId = (await CreateProject(repository: projects, ids: FakeIdGenerator(), clock: clock)(
      name: 'Браслет',
    )).valueOrNull!.id;
    patterns.byProject[projectId] = ImagePattern(id: 'pat-1', projectId: projectId, pages: _pages);
  });

  BookWorkCubit create({Duration delay = const Duration(milliseconds: 250)}) => BookWorkCubit(
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
    saveDelay: delay,
  );

  Future<BookWorkCubit> loaded() async {
    final BookWorkCubit cubit = create();
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  /// Тест со своими часами: debounce проверяем, не ожидая реального времени.
  void inFakeTime(void Function(FakeAsync async, BookWorkCubit cubit) body) {
    fakeAsync((async) {
      final BookWorkCubit cubit = create();
      unawaited(cubit.load());
      async.flushMicrotasks();
      body(async, cubit);
      unawaited(cubit.close());
      async.flushMicrotasks();
    });
  }

  group('загрузка', () {
    test('первый раз: первая страница, линейка вверху у каждой страницы', () async {
      final BookWorkCubit cubit = await loaded();

      expect(cubit.state.status, BookWorkStatus.ready);
      expect(cubit.state.projectName, 'Браслет');
      expect(cubit.state.pageIndex, 0);
      expect(cubit.state.pages, _pages);
      expect(cubit.state.work.ruler, RulerState.initial(1000));
      expect(cubit.state.works.keys, <String>['pg-1', 'pg-2', 'pg-3']);
    });

    test('запомненное восстанавливается: страница, линейка и вид каждой страницы', () async {
      const RulerState savedRuler = RulerState(
        top: 200,
        height: 20,
        step: 10,
        highlight: RulerHighlight.pink,
        row: 12,
      );
      work.currentPages['pat-1'] = 'pg-2';
      work.pages['pg-2'] = const PageWork(
        pageId: 'pg-2',
        ruler: savedRuler,
        viewport: PageViewport(scale: 3, dx: -5, dy: -9),
      );

      final BookWorkCubit cubit = await loaded();

      expect(cubit.state.pageIndex, 1);
      expect(cubit.state.work.ruler, savedRuler);
      expect(cubit.state.work.viewport, const PageViewport(scale: 3, dx: -5, dy: -9));
      expect(cubit.state.works['pg-1']!.ruler, RulerState.initial(1000));
    });

    test('запомненная страница пропала из схемы: открывается первая', () async {
      work.currentPages['pat-1'] = 'удалена';

      expect((await loaded()).state.pageIndex, 0);
    });

    test('линейка, не помещающаяся в страницу, подгоняется под неё', () async {
      work.pages['pg-2'] = const PageWork(
        pageId: 'pg-2',
        ruler: RulerState(top: 900, height: 50, step: 50, highlight: RulerHighlight.yellow, row: 5),
      );
      work.currentPages['pat-1'] = 'pg-2';

      final BookWorkCubit cubit = await loaded();

      expect(cubit.state.work.ruler.bottom, lessThanOrEqualTo(500));
    });

    test('у проекта нет схемы — failed', () async {
      patterns.byProject.clear();
      final BookWorkCubit cubit = await loaded();

      expect(cubit.state.status, BookWorkStatus.failed);
    });

    test('схема без страниц — failed', () async {
      patterns.byProject[projectId] = ImagePattern(
        id: 'pat-1',
        projectId: projectId,
        pages: const <ImagePatternPage>[],
      );

      expect((await loaded()).state.status, BookWorkStatus.failed);
    });

    test('ошибка чтения запомненного — failed', () async {
      work.failure = const StorageFailure('диск');

      expect((await loaded()).state.status, BookWorkStatus.failed);
    });

    test('неизвестный проект — failed', () async {
      projects.projects.clear();

      expect((await loaded()).state.status, BookWorkStatus.failed);
    });
  });

  group('сдвиг линейки', () {
    test('«следующий ряд» и «назад» двигают линейку на шаг и меняют номер ряда', () async {
      final BookWorkCubit cubit = await loaded();
      final double step = cubit.state.work.ruler.step;

      cubit.nextRow();
      cubit.nextRow();
      expect(cubit.state.work.ruler.top, step * 2);
      expect(cubit.state.work.ruler.row, 3);

      cubit.previousRow();
      expect(cubit.state.work.ruler.top, step);
      expect(cubit.state.work.ruler.row, 2);
    });

    test('у границ страницы сдвиг не выходит за неё, ряд не меняется', () async {
      final BookWorkCubit cubit = await loaded();
      cubit.previousRow();
      expect(cubit.state.work.ruler, RulerState.initial(1000));
      expect(cubit.state.canRetreat, isFalse);

      cubit.setRulerStep(5000);
      cubit.nextRow();
      cubit.nextRow();
      expect(cubit.state.work.ruler.bottom, 1000);
      expect(cubit.state.canAdvance, isFalse);
      final int row = cubit.state.work.ruler.row;
      cubit.nextRow();
      expect(cubit.state.work.ruler.row, row);
    });

    test('смена шага влияет на следующий сдвиг', () async {
      final BookWorkCubit cubit = await loaded();

      cubit.setRulerStep(10);
      cubit.nextRow();

      expect(cubit.state.work.ruler.top, 10);
    });

    test('высота и цвет подсветки меняются', () async {
      final BookWorkCubit cubit = await loaded();

      cubit.setRulerHeight(60);
      cubit.setHighlight(RulerHighlight.blue);

      expect(cubit.state.work.ruler.height, 60);
      expect(cubit.state.work.ruler.highlight, RulerHighlight.blue);
    });

    test('у каждой страницы своя линейка', () async {
      final BookWorkCubit cubit = await loaded();
      cubit.nextRow();
      cubit.nextRow();

      cubit.selectPage(1);
      expect(cubit.state.work.ruler, RulerState.initial(500));
      cubit.nextRow();

      cubit.selectPage(0);
      expect(cubit.state.work.ruler.row, 3);
      expect(cubit.state.works['pg-2']!.ruler.row, 2);
    });
  });

  group('страницы', () {
    test('selectPage ограничен существующими страницами', () async {
      final BookWorkCubit cubit = await loaded();

      cubit.selectPage(-1);
      cubit.selectPage(3);
      expect(cubit.state.pageIndex, 0);

      cubit.selectPage(2);
      expect(cubit.state.pageIndex, 2);
    });

    test('до загрузки команды игнорируются', () {
      final BookWorkCubit cubit = create();
      addTearDown(cubit.close);

      cubit
        ..nextRow()
        ..previousRow()
        ..selectPage(1)
        ..updateNotes('х')
        ..setViewport(const PageViewport(scale: 2, dx: 0, dy: 0));

      expect(cubit.state.status, BookWorkStatus.loading);
    });
  });

  group('сохранение (debounce)', () {
    test('несколько быстрых сдвигов дают одну запись после паузы', () {
      inFakeTime((async, cubit) {
        cubit.nextRow();
        async.elapse(const Duration(milliseconds: 100));
        cubit.nextRow();
        async.elapse(const Duration(milliseconds: 100));
        cubit.nextRow();
        expect(work.saves, 0);

        async.elapse(const Duration(milliseconds: 250));

        expect(work.saves, 1);
        expect(work.pages['pg-1']!.ruler.row, 4);
      });
    });

    test('задержка записи не больше 300 мс', () {
      expect(create().saveDelay, lessThanOrEqualTo(const Duration(milliseconds: 300)));
    });

    test('закрытие экрана записывает то, что ещё не записано', () async {
      final BookWorkCubit cubit = create();
      await cubit.load();
      cubit.nextRow();
      cubit.selectPage(2);
      cubit.updateNotes('заметка');
      expect(work.saves, 0);

      await cubit.close();

      expect(work.pages['pg-1']!.ruler.row, 2);
      expect(work.currentPages['pat-1'], 'pg-3');
      expect(projects.projects[projectId]!.notes, 'заметка');
    });

    test('после пересоздания экрана положение и страница те же', () async {
      final BookWorkCubit first = create();
      await first.load();
      first.nextRow();
      first.nextRow();
      first.selectPage(1);
      first.nextRow();
      first.setViewport(const PageViewport(scale: 4, dx: -20, dy: -40));
      await first.close();

      final BookWorkCubit second = await loaded();

      expect(second.state.pageIndex, 1);
      expect(second.state.work.ruler.row, 2);
      expect(second.state.work.viewport, const PageViewport(scale: 4, dx: -20, dy: -40));
      expect(second.state.works['pg-1']!.ruler.row, 3);
    });

    test('вид: повтор того же значения ничего не пишет', () {
      inFakeTime((async, cubit) {
        cubit.setViewport(const PageViewport(scale: 2, dx: 0, dy: 0));
        async.elapse(const Duration(seconds: 1));
        final int saves = work.saves;

        cubit.setViewport(const PageViewport(scale: 2, dx: 0, dy: 0));
        async.elapse(const Duration(seconds: 1));

        expect(work.saves, saves);
      });
    });

    test('сбой записи показывается и снимается следующей удачной записью; потерянное повторяется', () {
      inFakeTime((async, cubit) {
        work.failure = const StorageFailure('диск полон');
        cubit.nextRow();
        async.elapse(const Duration(milliseconds: 300));
        expect(cubit.state.saveFailed, isTrue);

        work.failure = null;
        cubit.setHighlight(RulerHighlight.green);
        async.elapse(const Duration(milliseconds: 300));

        expect(cubit.state.saveFailed, isFalse);
        expect(work.pages['pg-1']!.ruler.row, 2);
        expect(work.pages['pg-1']!.ruler.highlight, RulerHighlight.green);
      });
    });
  });

  group('надёжность записи', () {
    test('сбой сам повторяется без нового ввода, пока запись не удастся', () {
      inFakeTime((async, cubit) {
        work.failure = const StorageFailure('занято');
        cubit.nextRow();
        async.elapse(const Duration(milliseconds: 300));
        expect(cubit.state.saveFailed, isTrue);

        work.failure = null;
        async.elapse(const Duration(seconds: 5));

        expect(cubit.state.saveFailed, isFalse);
        expect(work.pages['pg-1']!.ruler.row, 2);
      });
    });

    test('неожиданное исключение не ломает закрытие и очередь записей', () async {
      final BookWorkCubit cubit = create();
      await cubit.load();
      cubit.nextRow();
      work.throwOnSave = true;

      await cubit.close();

      expect(cubit.isClosed, isTrue);
    });
  });

  group('проект', () {
    test('первый сдвиг переводит «идею» в «в работе»; без сдвига статус не меняется', () {
      inFakeTime((async, cubit) {
        cubit.selectPage(1);
        cubit.setHighlight(RulerHighlight.pink);
        async.elapse(const Duration(seconds: 1));
        expect(projects.projects[projectId]!.status, ProjectStatus.idea);

        clock.advance(const Duration(hours: 1));
        cubit.nextRow();
        async.elapse(const Duration(seconds: 1));

        expect(projects.projects[projectId]!.status, ProjectStatus.inProgress);
        expect(projects.projects[projectId]!.lastWorkedAt, clock.now());
      });
    });

    test('заметки сохраняются в проект и видны в состоянии', () {
      inFakeTime((async, cubit) {
        cubit.updateNotes('зелёный ряд 4');
        expect(cubit.state.notes, 'зелёный ряд 4');
        async.elapse(const Duration(seconds: 1));

        expect(projects.projects[projectId]!.notes, 'зелёный ряд 4');
      });
    });
  });

  group('направление, отмена, конец страницы', () {
    test('снизу вверх: линейка уходит к низу, следующий ряд сдвигает вверх', () async {
      final BookWorkCubit cubit = await loaded();
      cubit.setDirection(RowDirection.bottomUp);
      final RulerState start = cubit.state.work.ruler;
      expect(start.bottom, 1000);
      expect(cubit.state.canAdvance, isTrue);
      expect(cubit.state.canRetreat, isFalse);

      cubit.nextRow();
      expect(cubit.state.work.ruler.top, lessThan(start.top));
      expect(cubit.state.work.ruler.row, 2);
    });

    test('направление берут и страницы, где ещё не начали, а начатые остаются как были', () async {
      final BookWorkCubit cubit = await loaded();
      cubit.nextRow();
      cubit.selectPage(1);
      cubit.setDirection(RowDirection.bottomUp);

      expect(cubit.state.work.ruler.direction, RowDirection.bottomUp);
      expect(cubit.state.works['pg-3']!.ruler.direction, RowDirection.bottomUp);
      expect(cubit.state.works['pg-1']!.ruler.direction, RowDirection.topDown);
      await cubit.close();
    });

    test('«Отменить» возвращает линейку и ряд, подсказка исчезает', () async {
      final BookWorkCubit cubit = await loaded();
      final RulerState before = cubit.state.work.ruler;
      cubit.nextRow();
      expect(cubit.state.undoRuler, before);

      cubit.undoRow();
      expect(cubit.state.work.ruler, before);
      expect(cubit.state.undoRuler, isNull);
    });

    test('настройка линейки и смена страницы убирают подсказку «Отменить»', () async {
      final BookWorkCubit cubit = await loaded();
      cubit.nextRow();
      cubit.setRulerHeight(50);
      expect(cubit.state.undoRuler, isNull);

      cubit.nextRow();
      cubit.selectPage(1);
      expect(cubit.state.undoRuler, isNull);
      cubit.dismissUndo();
    });

    test('последний ряд и переход на следующую страницу', () async {
      final BookWorkCubit cubit = await loaded();
      cubit.setRulerStep(5000);
      cubit.nextRow();
      cubit.nextRow();
      expect(cubit.state.isLastRow, isTrue);
      expect(cubit.state.hasNextPage, isTrue);

      cubit.nextPage();
      expect(cubit.state.pageIndex, 1);
      cubit.selectPage(2);
      expect(cubit.state.hasNextPage, isFalse);
      cubit.nextPage();
      expect(cubit.state.pageIndex, 2);
    });

    test('панель сворачивается и разворачивается', () async {
      final BookWorkCubit cubit = await loaded();
      cubit.setPanelCollapsed(collapsed: true);
      expect(cubit.state.panelCollapsed, isTrue);
      cubit.setPanelCollapsed(collapsed: false);
      expect(cubit.state.panelCollapsed, isFalse);
    });
  });
}
