import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/steps/repeat.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/step_template.dart';
import 'package:beading/domain/steps/steps_progress.dart';
import 'package:beading/domain/steps/use_cases/create_step_pattern.dart';
import 'package:beading/domain/steps/use_cases/save_step_pattern.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/steps/new_steps_cubit.dart';
import 'package:beading/presentation/steps/new_steps_screen.dart';
import 'package:beading/presentation/steps/steps_editor_cubit.dart';
import 'package:beading/presentation/steps/steps_editor_screen.dart';
import 'package:beading/presentation/steps/steps_editor_state.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_image_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_steps.dart';

PatternColor _ruby() => PatternColor(
  rgb: const Rgb(200, 10, 20),
  name: 'Рубин',
  components: const <CatalogRef>[CatalogRef(brand: 'Miyuki', code: 'DB0010')],
);

PatternColor _blue() => PatternColor(
  rgb: const Rgb(0, 0, 200),
  name: 'Синий',
  components: const <CatalogRef>[CatalogRef(brand: 'Miyuki', code: 'DB0020')],
);

StepPattern _pattern(String projectId) => StepPattern(
  id: 'sp1',
  projectId: projectId,
  sections: const <StepSection>[
    StepSection(
      id: 's1',
      title: 'Ёлочка',
      steps: <InstructionStep>[
        InstructionStep(id: 'a', text: 'Первый'),
        InstructionStep(id: 'b', text: 'Второй'),
        InstructionStep(id: 'c', text: 'Третий'),
      ],
    ),
    StepSection(
      id: 's2',
      steps: <InstructionStep>[InstructionStep(id: 'd', text: 'Четвёртый')],
    ),
  ],
);

void main() {
  late FakeProjectRepository projects;
  late FakeStepPatternRepository patterns;
  late FakeStepsProgressStore progress;
  late FakeFileStore files;
  late FakeImageProcessor processor;
  late FakeIdGenerator ids;
  late FakeClock clock;
  late String projectId;

  setUp(() async {
    projects = FakeProjectRepository();
    patterns = FakeStepPatternRepository();
    progress = FakeStepsProgressStore();
    files = FakeFileStore();
    processor = FakeImageProcessor();
    ids = FakeIdGenerator();
    clock = FakeClock(DateTime.utc(2026, 11, 16, 9));
    projectId = (await CreateProject(repository: projects, ids: ids, clock: clock)(
      name: 'Жгут',
      contentKind: ContentKind.steps,
    )).valueOrNull!.id;
    patterns.byProject[projectId] = _pattern(projectId);
  });

  StepsEditorCubit newCubit({Duration debounce = const Duration(milliseconds: 10)}) => StepsEditorCubit(
    projectId: projectId,
    projects: projects,
    patterns: patterns,
    savePattern: SaveStepPattern(patterns: patterns, files: files, progress: progress),
    processor: processor,
    files: files,
    ids: ids,
    debounce: debounce,
    undoDuration: const Duration(milliseconds: 40),
  );

  Future<StepsEditorCubit> loaded() async {
    final StepsEditorCubit cubit = newCubit();
    await cubit.load();
    return cubit;
  }

  Future<void> pause([int ms = 80]) => Future<void>.delayed(Duration(milliseconds: ms));

  group('StepsEditorCubit', () {
    test('load: документ и название; нет инструкции — сбой', () async {
      final StepsEditorCubit cubit = await loaded();
      expect(cubit.state.status, StepsEditorStatus.ready);
      expect(cubit.state.projectName, 'Жгут');
      await cubit.close();
      patterns.byProject.clear();
      final StepsEditorCubit broken = await loaded();
      expect(broken.state.status, StepsEditorStatus.failed);
      await broken.close();
    });

    test('правка текста уходит в автосохранение после паузы: сначала «идёт запись», потом «сохранено»', () async {
      final StepsEditorCubit cubit = await loaded();
      cubit.setStepText('a', 'Новый текст');
      expect(cubit.state.save, StepsSaveStatus.pending);
      expect(patterns.byProject[projectId]!.allSteps.first.text, 'Первый', reason: 'до паузы ничего не записано');
      await pause();
      expect(cubit.state.save, StepsSaveStatus.saved);
      expect(patterns.byProject[projectId]!.allSteps.first.text, 'Новый текст');
      await cubit.close();
    });

    test('закрытие экрана дописывает несохранённую правку', () async {
      final StepsEditorCubit cubit = newCubit(debounce: const Duration(seconds: 30));
      await cubit.load();
      cubit.setStepText('a', 'Не потеряется');
      await cubit.close();
      expect(patterns.byProject[projectId]!.allSteps.first.text, 'Не потеряется');
    });

    test('сбой записи показывается и снимается следующей удачной записью', () async {
      final StepsEditorCubit cubit = await loaded();
      patterns.failNextSave = const StorageFailure('диск');
      cubit.setStepText('a', 'x');
      await pause();
      expect(cubit.state.save, StepsSaveStatus.failed);
      cubit.setStepText('a', 'xy');
      await pause();
      expect(cubit.state.save, StepsSaveStatus.saved);
      await cubit.close();
    });

    test('добавить шаг и секцию, переименовать, повтор, дублировать, переставить и удалить секцию', () async {
      final StepsEditorCubit cubit = await loaded();
      final String? added = cubit.addStep('s2');
      expect(cubit.state.pattern!.sections[1].steps.last.id, added);
      cubit
        ..addSection()
        ..renameSection('s2', 'Сетка')
        ..setSectionRepeat('s2', const Repeat.times(4))
        ..moveSection('s2', -1)
        ..duplicateSection('s1');
      final List<StepSection> sections = cubit.state.pattern!.sections;
      expect(sections.map((s) => s.title), <String>['Сетка', 'Ёлочка', 'Ёлочка', '']);
      expect(sections[0].repeat.passes, 4);
      expect(sections[2].steps.map((s) => s.text), <String>['Первый', 'Второй', 'Третий']);
      expect(sections[2].steps.first.id, isNot('a'), reason: 'у копии свои id');
      cubit.deleteSection(sections[3].id);
      expect(cubit.state.pattern!.sections, hasLength(3));
      await cubit.close();
    });

    test('перестановка шагов перетаскиванием', () async {
      final StepsEditorCubit cubit = await loaded();
      cubit.reorderSteps('s1', 0, 3); // первый — в конец
      expect(cubit.state.pattern!.sections.first.steps.map((s) => s.id), <String>['b', 'c', 'a']);
      cubit.reorderSteps('s1', 2, 0);
      expect(cubit.state.pattern!.sections.first.steps.map((s) => s.id), <String>['a', 'b', 'c']);
      await cubit.close();
    });

    test('удаление шага: баннер, отмена возвращает на место; файлы его картинок живут до конца баннера', () async {
      final StepsEditorCubit cubit = await loaded();
      cubit.deleteStep('b');
      expect(cubit.state.deleted!.step.id, 'b');
      expect(cubit.state.stepById('b'), isNull);
      cubit.undoDelete();
      expect(cubit.state.pattern!.sections.first.steps.map((s) => s.id), <String>['a', 'b', 'c']);
      expect(cubit.state.deleted, isNull);

      await cubit.addPhotos('c', <Uint8List>[
        Uint8List.fromList(<int>[1]),
      ]);
      await pause();
      cubit.deleteStep('c');
      await pause(30);
      expect(
        patterns.byProject[projectId]!.allSteps.map((s) => s.id),
        isNot(contains('c')),
        reason: 'документ пишется сразу',
      );
      expect(files.files, hasLength(1), reason: 'файл картинки не трогаем, пока шаг можно вернуть');
      await pause(120);
      expect(cubit.state.deleted, isNull);
      expect(files.files, isEmpty, reason: 'баннер ушёл: файл убран при записи');
      await cubit.close();
    });

    test('отмена удаления возвращает шаг вместе с картинкой, файл на месте', () async {
      final StepsEditorCubit cubit = await loaded();
      await cubit.addPhotos('b', <Uint8List>[
        Uint8List.fromList(<int>[1]),
      ]);
      await pause();
      cubit.deleteStep('b');
      await pause(20);
      cubit.undoDelete();
      await pause(100);
      expect(cubit.state.stepById('b')!.imageIds, hasLength(1));
      expect(patterns.byProject[projectId]!.images, hasLength(1));
      expect(files.files, hasLength(1));
      await cubit.close();
    });

    test('фото обработалось, а шаг уже удалён: файл не остаётся', () async {
      final StepsEditorCubit cubit = await loaded();
      final Future<void> adding = cubit.addPhotos('a', <Uint8List>[
        Uint8List.fromList(<int>[1]),
      ]);
      cubit.deleteStep('a');
      await adding;
      expect(files.files, isEmpty);
      await cubit.close();
    });

    test('удаление шага под курсором: прогресс переезжает на ближайший оставшийся', () async {
      progress.byPattern['sp1'] = const StepsProgress(sectionId: 's1', sectionPass: 1, stepId: 'b', stepPass: 1);
      final StepsEditorCubit cubit = await loaded();
      cubit.deleteStep('b');
      await pause(150);
      final StepsProgress saved = progress.byPattern['sp1']!;
      expect(<String>['a', 'c'], contains(saved.stepId));
      await cubit.close();
    });

    test('бусины: цвет попадает в палитру один раз, число складывается, нулевое убирает бусину', () async {
      final StepsEditorCubit cubit = await loaded();
      cubit
        ..addBead('a', _ruby(), count: 2)
        ..addBead('b', _ruby())
        ..addBead('a', _ruby())
        ..addBead('a', _blue());
      expect(cubit.state.pattern!.palette, hasLength(2));
      expect(cubit.state.stepById('a')!.beads, const <StepBead>[
        StepBead(colorIndex: 0, count: 3),
        StepBead(colorIndex: 1, count: 1),
      ]);
      cubit.setBeadCount('a', 1, 0);
      expect(cubit.state.stepById('a')!.beads, hasLength(1));
      await cubit.close();
    });

    test('фото: файл пишется в хранилище, картинка привязана к шагу; убрать фото; порядок', () async {
      final StepsEditorCubit cubit = await loaded();
      await cubit.addPhotos('a', <Uint8List>[
        Uint8List.fromList(<int>[1]),
        Uint8List.fromList(<int>[2]),
      ]);
      final StepInstructionRef step = StepInstructionRef(cubit.state.stepById('a')!);
      expect(step.imageIds, hasLength(2));
      expect(cubit.state.pattern!.images, hasLength(2));
      expect(files.files, hasLength(2));
      cubit.reorderImages('a', 0, 2);
      expect(cubit.state.stepById('a')!.imageIds.last, step.imageIds.first);
      cubit.removeImage('a', step.imageIds.first);
      expect(cubit.state.stepById('a')!.imageIds, hasLength(1));
      await pause();
      expect(files.files, hasLength(1), reason: 'файл неиспользуемой картинки убран при записи');
      await cubit.close();
    });

    test('фото не обработалось: ошибка и шаг не меняется', () async {
      processor.failure = const ValidationFailure('битое');
      final StepsEditorCubit cubit = await loaded();
      await cubit.addPhotos('a', <Uint8List>[
        Uint8List.fromList(<int>[1]),
      ]);
      expect(cubit.state.photoFailed, isTrue);
      expect(cubit.state.stepById('a')!.imageIds, isEmpty);
      await cubit.close();
    });
  });

  group('NewStepsCubit', () {
    late FakeBookImageSource source;
    late NewStepsCubit cubit;

    NewStepsCubit make(List<StepTemplate> templates) => NewStepsCubit(
      create: CreateStepPattern(
        createProject: CreateProject(repository: projects, ids: ids, clock: clock),
        projects: projects,
        patterns: patterns,
        templates: FakeStepTemplateSource(templates),
        processor: processor,
        files: files,
        ids: ids,
      ),
      templates: FakeStepTemplateSource(templates),
      photos: source,
    );

    setUp(() => source = FakeBookImageSource());

    test('пустая: проект создан, id отдан экрану', () async {
      cubit = make(const <StepTemplate>[]);
      await cubit.createEmpty('Новая');
      expect(cubit.state.createdId, isNotNull);
      expect(patterns.byProject[cubit.state.createdId!], isNotNull);
      await cubit.close();
    });

    test('из фото: пустой выбор ничего не создаёт, фото создают проект по шагу на фото', () async {
      cubit = make(const <StepTemplate>[]);
      await cubit.fromPhotos('Фото', camera: false);
      expect(cubit.state.createdId, isNull);
      expect(cubit.state.busy, isFalse);
      source.next = Success<List<PickedBookFile>>(<PickedBookFile>[
        PickedBookFile(name: 'a.jpg', bytes: Uint8List.fromList(<int>[1])),
        PickedBookFile(name: 'b.jpg', bytes: Uint8List.fromList(<int>[2])),
      ]);
      await cubit.fromPhotos('Фото', camera: true);
      expect(source.calls, <String>['photos', 'camera']);
      expect(patterns.byProject[cubit.state.createdId!]!.allSteps, hasLength(2));
      await cubit.close();
    });

    test('нет доступа к камере: сообщение, проект не создан', () async {
      cubit = make(const <StepTemplate>[]);
      source.next = const Err<List<PickedBookFile>>(StorageFailure('denied'));
      await cubit.fromPhotos('Фото', camera: true);
      expect(cubit.state.problem, NewStepsProblem.photosFailed);
      expect(cubit.state.createdId, isNull);
      await cubit.close();
    });

    test('шаблон: список загружается и создаётся копия; неизвестный шаблон — ошибка', () async {
      const StepTemplate t = StepTemplate(
        id: 't',
        title: 'Образец',
        sections: <StepSection>[
          StepSection(
            id: 'x',
            steps: <InstructionStep>[InstructionStep(id: 'y', text: 'Шаг')],
          ),
        ],
      );
      cubit = make(<StepTemplate>[t]);
      await cubit.load();
      expect(cubit.state.templates, hasLength(1));
      await cubit.fromTemplate('Из шаблона', 'нет');
      expect(cubit.state.problem, NewStepsProblem.createFailed);
      await cubit.fromTemplate('Из шаблона', 't');
      expect(patterns.byProject[cubit.state.createdId!]!.templateId, 't');
      await cubit.close();
    });
  });

  group('экраны', () {
    Widget app(Widget home) => CupertinoApp(
      theme: AppTheme.light,
      builder: AppTheme.builder,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump();
      await tester.pump();
    }

    Future<StepsEditorCubit> openEditor(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final StepsEditorCubit cubit = newCubit();
      await tester.pumpWidget(
        app(
          BlocProvider<StepsEditorCubit>.value(
            value: cubit,
            child: StepsEditorScreen(
              files: files,
              photos: FakeBookImageSource(),
              loadCatalog: () async => <PatternColor>[_ruby()],
            ),
          ),
        ),
      );
      await tester.runAsync(cubit.load);
      await tester.pump();
      await tester.pump();
      return cubit;
    }

    testWidgets('редактор: секции и шаги, «Сохранено», добавление шага и секции', (tester) async {
      final StepsEditorCubit cubit = await openEditor(tester);
      expect(find.text('Первый'), findsOneWidget);
      expect(find.text('Четвёртый'), findsOneWidget);
      expect(find.text('Сохранено'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('add-step-s2')));
      await tester.pump();
      expect(cubit.state.pattern!.sections[1].steps, hasLength(2));
      expect(find.text('Сохраняю…'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('steps-add-section')));
      await tester.pump();
      expect(cubit.state.pattern!.sections, hasLength(3));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(cubit.close);
    });

    testWidgets('смахнуть шаг: баннер «Шаг удалён», «Отменить» возвращает его', (tester) async {
      final StepsEditorCubit cubit = await openEditor(tester);
      await tester.drag(find.byKey(const ValueKey<String>('dismiss-b')), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Шаг удалён'), findsOneWidget);
      expect(find.text('Второй'), findsNothing);
      await tester.tap(find.byKey(const ValueKey<String>('steps-undo')));
      await tester.pump();
      expect(find.text('Второй'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(cubit.close);
    });

    testWidgets('страница шага: текст, бусины из каталога, повтор; удаление шага', (tester) async {
      final StepsEditorCubit cubit = await openEditor(tester);
      await tester.tap(find.text('Первый'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey<String>('step-text')), 'Нанижи три бусины');
      await tester.pump();
      expect(cubit.state.stepById('a')!.text, 'Нанижи три бусины');

      await tester.tap(find.byKey(const ValueKey<String>('step-add-beads')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Рубин').first);
      await tester.pumpAndSettle();
      expect(cubit.state.stepById('a')!.beads.single.count, 1);
      await tester.tap(find.byKey(const ValueKey<String>('count-more')).first);
      await tester.pump();
      expect(cubit.state.stepById('a')!.beads.single.count, 2);

      await tester.tap(find.text('Несколько раз'));
      await tester.pump();
      expect(cubit.state.stepById('a')!.repeat.passes, 2);

      await tester.tap(find.byKey(const ValueKey<String>('step-delete')));
      await tester.pumpAndSettle();
      expect(cubit.state.stepById('a'), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(cubit.close);
    });

    testWidgets('новая инструкция: пустая создаётся и экран закрывается с id', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final NewStepsCubit cubit = NewStepsCubit(
        create: CreateStepPattern(
          createProject: CreateProject(repository: projects, ids: ids, clock: clock),
          projects: projects,
          patterns: patterns,
          templates: FakeStepTemplateSource(const <StepTemplate>[]),
          processor: processor,
          files: files,
          ids: ids,
        ),
        templates: FakeStepTemplateSource(const <StepTemplate>[]),
        photos: FakeBookImageSource(),
      );
      String? result;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => CupertinoButton(
              onPressed: () async => result = await Navigator.of(context).push<String>(
                CupertinoPageRoute<String>(
                  builder: (_) => BlocProvider<NewStepsCubit>.value(value: cubit, child: const NewStepsScreen()),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Из фото'), findsOneWidget);
      expect(find.text('Шаблоны'), findsNothing, reason: 'шаблонов пока нет (T33e)');
      await tester.tap(find.byKey(const ValueKey<String>('steps-new-empty')));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(patterns.byProject[result!], isNotNull);
      await tester.runAsync(cubit.close);
    });
  });
}

/// Небольшая обёртка, чтобы тест читался: id картинок шага.
class StepInstructionRef {
  const StepInstructionRef(this.step);

  final InstructionStep step;

  List<String> get imageIds => step.imageIds;
}
