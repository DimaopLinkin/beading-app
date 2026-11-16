import 'dart:typed_data';

import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/image_pattern/book_work/record_book_progress.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/change_project_status.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:beading/domain/steps/repeat.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/steps_progress.dart';
import 'package:beading/domain/steps/use_cases/step_navigation.dart';
import 'package:beading/domain/weaving/work_session_tracker.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/steps/step_widgets.dart';
import 'package:beading/presentation/steps/steps_work_cubit.dart';
import 'package:beading/presentation/steps/steps_work_screen.dart';
import 'package:beading/presentation/steps/steps_work_state.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_image_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_steps.dart';
import '../../support/fake_work_sessions.dart';
import '../../support/test_images.dart';

/// Секция 1 (2 раза): «Нанижи» (3 раза), «Проведи»; секция 2: «Закрой» (до нужной длины).
StepPattern _pattern(String projectId, {List<StepImage> images = const <StepImage>[]}) => StepPattern(
  id: 'sp1',
  projectId: projectId,
  palette: <PatternColor>[
    PatternColor(
      rgb: const Rgb(200, 10, 20),
      name: 'Рубин',
      components: const <CatalogRef>[CatalogRef(brand: 'Miyuki', code: 'DB0010')],
    ),
  ],
  images: images,
  sections: <StepSection>[
    StepSection(
      id: 's1',
      title: 'Ёлочка',
      repeat: const Repeat.times(2),
      steps: <InstructionStep>[
        InstructionStep(
          id: 'a',
          text: 'Нанижи бусины',
          repeat: const Repeat.times(3),
          beads: const <StepBead>[StepBead(colorIndex: 0, count: 3)],
          imageIds: images.isEmpty ? const <String>[] : <String>[images.first.id],
        ),
        const InstructionStep(id: 'b', text: 'Проведи нить'),
      ],
    ),
    const StepSection(
      id: 's2',
      steps: <InstructionStep>[InstructionStep(id: 'c', text: 'Закрой ряд', repeat: Repeat.untilDone())],
    ),
  ],
);

void main() {
  late FakeProjectRepository projects;
  late FakeStepPatternRepository patterns;
  late FakeStepsProgressStore store;
  late FakeWorkSessionRepository sessions;
  late FakeFileStore files;
  late FakeClock clock;
  late BroadcastAppEvents events;
  late String projectId;

  setUp(() async {
    projects = FakeProjectRepository();
    patterns = FakeStepPatternRepository();
    store = FakeStepsProgressStore();
    sessions = FakeWorkSessionRepository();
    files = FakeFileStore();
    clock = FakeClock(DateTime.utc(2026, 11, 16, 9));
    events = BroadcastAppEvents();
    projectId = (await CreateProject(repository: projects, ids: FakeIdGenerator(), clock: clock)(
      name: 'Жгут',
      contentKind: ContentKind.steps,
    )).valueOrNull!.id;
    patterns.byProject[projectId] = _pattern(projectId);
  });

  tearDown(() => events.dispose());

  StepsWorkCubit newCubit() {
    final ChangeProjectStatus change = ChangeProjectStatus(repository: projects, events: events);
    return StepsWorkCubit(
      projectId: projectId,
      projects: projects,
      patterns: patterns,
      navigation: StepNavigation(store),
      recordProgress: RecordBookProgress(
        projects: projects,
        changeStatus: change,
        touch: TouchProject(repository: projects, clock: clock),
      ),
      changeStatus: change,
      tracker: WorkSessionTracker(sessions: sessions, clock: clock),
    );
  }

  Future<StepsWorkCubit> loaded() async {
    final StepsWorkCubit cubit = newCubit();
    await cubit.load();
    return cubit;
  }

  group('StepsWorkCubit', () {
    test('load: начало инструкции, номер шага считает написанные шаги', () async {
      final StepsWorkCubit cubit = await loaded();
      final StepsWorkState s = cubit.state;
      expect(s.status, StepsWorkStatus.ready);
      expect(s.step!.id, 'a');
      expect(s.stepNumber, 1);
      expect(s.totalSteps, 3);
      expect(s.sectionNumber, (1, 2));
      expect(s.isAtStart, isTrue);
      await cubit.close();
    });

    test('load восстанавливает сохранённое место', () async {
      store.byPattern['sp1'] = const StepsProgress(sectionId: 's1', sectionPass: 2, stepId: 'b', stepPass: 1);
      final StepsWorkCubit cubit = await loaded();
      expect(cubit.state.step!.id, 'b');
      expect(cubit.state.progress!.sectionPass, 2);
      expect(cubit.state.stepNumber, 2);
      await cubit.close();
    });

    test('нет инструкции: экран сообщает о сбое', () async {
      patterns.byProject.clear();
      final StepsWorkCubit cubit = await loaded();
      expect(cubit.state.status, StepsWorkStatus.failed);
      await cubit.close();
    });

    test('next идёт по повторам шага, записывается и переводит проект в работу', () async {
      final StepsWorkCubit cubit = await loaded();
      cubit
        ..next()
        ..next();
      await cubit.close();
      expect(cubit.state.progress!.stepPass, 3);
      expect(store.byPattern['sp1']!.stepPass, 3);
      expect((await projects.get(projectId)).valueOrNull!.status, ProjectStatus.inProgress);
    });

    test('back возвращает на предыдущий проход, а в самом начале остаётся на месте', () async {
      final StepsWorkCubit cubit = await loaded();
      cubit
        ..back()
        ..next()
        ..back();
      await cubit.close();
      expect(cubit.state.progress!.stepPass, 1);
      expect(cubit.state.step!.id, 'a');
    });

    test('jumpTo переходит к шагу из списка', () async {
      final StepsWorkCubit cubit = await loaded();
      cubit.jumpTo('c');
      await cubit.close();
      expect(cubit.state.step!.id, 'c');
      expect(cubit.state.sectionNumber, (2, 2));
    });

    test('«Достаточно» доступно только у повторов «до нужной длины» и идёт дальше', () async {
      final StepsWorkCubit cubit = await loaded();
      expect(cubit.state.canSkipRepeat, isFalse);
      cubit.jumpTo('c');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(cubit.state.canSkipRepeat, isTrue);
      expect(cubit.state.isLastStep, isFalse, reason: 'повтор без счёта: дальше идёт ещё проход');
      cubit.skipRepeat();
      await cubit.close();
      expect(cubit.state.finished, isTrue);
    });

    test('последний шаг: finishWork заканчивает инструкцию и отмечает проект готовым', () async {
      patterns.byProject[projectId] = StepPattern(
        id: 'sp1',
        projectId: projectId,
        sections: const <StepSection>[
          StepSection(
            id: 's',
            steps: <InstructionStep>[InstructionStep(id: 'x', text: 'Единственный')],
          ),
        ],
      );
      final StepsWorkCubit cubit = await loaded();
      expect(cubit.state.isLastStep, isTrue);
      await cubit.finishWork();
      expect(cubit.state.finished, isTrue);
      expect(cubit.state.projectDone, isTrue);
      expect((await projects.get(projectId)).valueOrNull!.status, ProjectStatus.done);
      await cubit.close();
    });

    test('пустая инструкция: действия ничего не меняют', () async {
      patterns.byProject[projectId] = StepPattern(id: 'sp1', projectId: projectId, sections: const <StepSection>[]);
      final StepsWorkCubit cubit = await loaded();
      expect(cubit.state.isEmpty, isTrue);
      cubit
        ..next()
        ..back()
        ..skipRepeat();
      await cubit.close();
      expect(store.byPattern, isEmpty);
    });
  });

  group('StepsWorkScreen', () {
    Future<StepsWorkCubit> open(
      WidgetTester tester, {
      CupertinoThemeData? theme,
      Size size = const Size(430, 932),
    }) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final StepsWorkCubit cubit = newCubit();
      await tester.pumpWidget(
        CupertinoApp(
          theme: theme ?? AppTheme.light,
          builder: AppTheme.builder,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<StepsWorkCubit>.value(
            value: cubit,
            child: StepsWorkScreen(files: files, onOpenStats: () {}),
          ),
        ),
      );
      await tester.runAsync(cubit.load);
      await tester.pump();
      await tester.pump();
      return cubit;
    }

    Future<void> closeScreen(WidgetTester tester, StepsWorkCubit cubit) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(cubit.close);
    }

    testWidgets('шаг: номер, повтор N из M, текст, чип бусин, секция в панели', (tester) async {
      final StepsWorkCubit cubit = await open(tester);
      expect(find.text('Шаг 1 из 3'), findsOneWidget);
      expect(find.text('Секция 1 из 2 · Ёлочка'), findsOneWidget);
      expect(find.text('повтор 1 из 2'), findsOneWidget);
      expect(find.text('повтор 1 из 3'), findsOneWidget);
      expect(find.text('Нанижи бусины'), findsOneWidget);
      expect(find.text('3 × A'), findsOneWidget);
      expect(find.text('Готово, дальше'), findsOneWidget);
      expect(find.text('Достаточно'), findsNothing);
      await closeScreen(tester, cubit);
    });

    testWidgets('«Готово, дальше» двигает курсор; «Назад» возвращает', (tester) async {
      final StepsWorkCubit cubit = await open(tester);
      await tester.tap(find.byKey(const ValueKey<String>('steps-next')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(find.text('повтор 2 из 3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('steps-back')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(find.text('повтор 1 из 3'), findsOneWidget);
      await closeScreen(tester, cubit);
    });

    testWidgets('«до нужной длины»: «N-й повтор» без общего числа и кнопка «Достаточно»', (tester) async {
      store.byPattern['sp1'] = const StepsProgress(sectionId: 's2', sectionPass: 1, stepId: 'c', stepPass: 4);
      final StepsWorkCubit cubit = await open(tester);
      expect(find.text('4-й повтор'), findsOneWidget);
      expect(find.text('Достаточно'), findsOneWidget);
      await closeScreen(tester, cubit);
    });

    testWidgets('шаг без фото и без бусин показывает только текст; крупный шрифт не обрезает', (tester) async {
      store.byPattern['sp1'] = const StepsProgress(sectionId: 's1', sectionPass: 1, stepId: 'b', stepPass: 1);
      final StepsWorkCubit cubit = await open(tester, theme: AppTheme.dark, size: const Size(390, 700));
      expect(find.text('Проведи нить'), findsOneWidget);
      expect(find.byType(BeadChip), findsNothing);
      expect(tester.takeException(), isNull);
      await closeScreen(tester, cubit);
    });

    testWidgets('десять фото листаются, счётчик «1 из 10»; фото не загрузилось — заглушка', (tester) async {
      final Uint8List png = (await tester.runAsync(redBluePng))!;
      final List<StepImage> images = <StepImage>[
        for (int i = 0; i < 10; i++) StepImage(id: 'i$i', path: 'p/i$i.png', width: 4, height: 2),
      ];
      files.files['p/i0.png'] = png;
      patterns.byProject[projectId] = StepPattern(
        id: 'sp1',
        projectId: projectId,
        images: images,
        sections: <StepSection>[
          StepSection(
            id: 's',
            steps: <InstructionStep>[
              InstructionStep(id: 'x', text: 'Много фото', imageIds: <String>[for (final i in images) i.id]),
            ],
          ),
        ],
      );
      final StepsWorkCubit cubit = await open(tester);
      expect(find.text('1 из 10'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 из 10'), findsOneWidget);
      expect(find.text('Фото не загрузилось'), findsOneWidget, reason: 'файла второго фото нет');
      expect(find.text('Повторить'), findsOneWidget);
      await closeScreen(tester, cubit);
    });

    testWidgets('последний шаг: «Готово: отметить работу законченной» и затем «Работа закончена»', (tester) async {
      patterns.byProject[projectId] = StepPattern(
        id: 'sp1',
        projectId: projectId,
        sections: const <StepSection>[
          StepSection(
            id: 's',
            steps: <InstructionStep>[InstructionStep(id: 'x', text: 'Последний')],
          ),
        ],
      );
      final StepsWorkCubit cubit = await open(tester);
      expect(find.text('Готово: отметить работу законченной'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('steps-finish')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(find.text('Работа закончена'), findsOneWidget);
      await closeScreen(tester, cubit);
    });

    testWidgets('список шагов: касание строки переходит к шагу', (tester) async {
      final StepsWorkCubit cubit = await open(tester);
      await tester.tap(find.byKey(const ValueKey<String>('steps-list')));
      await tester.pumpAndSettle();
      expect(find.text('Список шагов'), findsOneWidget);
      expect(find.text('Закрой ряд'), findsOneWidget);
      await tester.tap(find.text('Закрой ряд'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pumpAndSettle();
      expect(cubit.state.step!.id, 'c');
      await closeScreen(tester, cubit);
    });

    testWidgets('пустая инструкция: сообщение, кнопки не падают', (tester) async {
      patterns.byProject[projectId] = StepPattern(id: 'sp1', projectId: projectId, sections: const <StepSection>[]);
      final StepsWorkCubit cubit = await open(tester);
      expect(find.text('В инструкции пока нет шагов.'), findsOneWidget);
      await closeScreen(tester, cubit);
    });
  });

  test('paletteLetter: A…Z, AA, AB', () {
    expect(paletteLetter(0), 'A');
    expect(paletteLetter(25), 'Z');
    expect(paletteLetter(26), 'AA');
    expect(paletteLetter(27), 'AB');
  });
}
