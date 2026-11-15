import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/load_project_preview.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/delete_project.dart';
import 'package:beading/domain/projects/use_cases/duplicate_project.dart';
import 'package:beading/domain/steps/repeat.dart';
import 'package:beading/domain/steps/step_materials.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/step_pattern_content.dart';
import 'package:beading/domain/steps/step_template.dart';
import 'package:beading/domain/steps/steps_progress.dart';
import 'package:beading/domain/steps/use_cases/create_step_pattern.dart';
import 'package:beading/domain/steps/use_cases/save_step_pattern.dart';
import 'package:beading/domain/steps/use_cases/step_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_image_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_steps.dart';

PatternColor blue() => PatternColor(
  rgb: const Rgb(0, 0, 200),
  name: 'Синий',
  components: const <CatalogRef>[CatalogRef(brand: 'Miyuki', code: 'DB0010')],
);

void main() {
  late FakeProjectRepository projects;
  Set<String> alive() => projects.projects.keys.toSet().difference(projects.deleted);
  late FakeStepPatternRepository patterns;
  late FakeStepsProgressStore progress;
  late FakeFileStore files;
  late FakeImageProcessor processor;
  late FakeIdGenerator ids;
  late FakeClock clock;
  late FakeStepTemplateSource templates;
  late CreateStepPattern create;

  final StepTemplate raw = StepTemplate(
    id: 'raw',
    title: 'Крестик (RAW)',
    palette: <PatternColor>[blue()],
    images: <StepTemplateImage>[
      StepTemplateImage(id: 't1', png: Uint8List.fromList(<int>[7]), width: 10, height: 20),
    ],
    sections: const <StepSection>[
      StepSection(
        id: 'ts',
        title: 'Первый ряд',
        repeat: Repeat.times(3),
        steps: <InstructionStep>[
          InstructionStep(
            id: 'tstep',
            text: 'Нанижи 4 бусины',
            imageIds: <String>['t1', 'нет-такой'],
            beads: <StepBead>[StepBead(colorIndex: 0, count: 4)],
          ),
        ],
      ),
    ],
  );

  setUp(() {
    projects = FakeProjectRepository();
    patterns = FakeStepPatternRepository();
    progress = FakeStepsProgressStore();
    files = FakeFileStore();
    processor = FakeImageProcessor();
    ids = FakeIdGenerator();
    clock = FakeClock(DateTime.utc(2026, 11, 15));
    templates = FakeStepTemplateSource(<StepTemplate>[raw]);
    create = CreateStepPattern(
      createProject: CreateProject(repository: projects, ids: ids, clock: clock),
      projects: projects,
      patterns: patterns,
      templates: templates,
      processor: processor,
      files: files,
      ids: ids,
    );
  });

  group('CreateStepPattern', () {
    test('пустая: проект steps/offLoom, одна секция с одним пустым шагом', () async {
      final Project project = (await create.empty(name: 'Жгут')).valueOrNull!;

      expect(project.contentKind, ContentKind.steps);
      expect(project.craft, Craft.beading);
      expect(project.technique, Technique.offLoom);
      final StepPattern pattern = patterns.byProject[project.id]!;
      expect(pattern.sections.single.steps, hasLength(1));
      expect(pattern.sections.single.steps.single.text, isEmpty);
      expect(pattern.templateId, isNull);
    });

    test('только для бисера', () async {
      final Result<Project> r = await create.empty(name: 'Х', technique: Technique.crossStitch);
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(alive(), isEmpty);
    });

    test('из шаблона: копия с новыми id, картинки в хранилище проекта, битая ссылка отброшена', () async {
      final Project project = (await create.fromTemplate(name: 'RAW', templateId: 'raw')).valueOrNull!;

      final StepPattern pattern = patterns.byProject[project.id]!;
      expect(pattern.templateId, 'raw');
      expect(pattern.palette, raw.palette);
      final InstructionStep step = pattern.sections.single.steps.single;
      expect(step.id, isNot('tstep'));
      expect(pattern.sections.single.id, isNot('ts'));
      expect(pattern.sections.single.repeat, const Repeat.times(3));
      expect(step.beads, raw.sections.single.steps.single.beads);
      expect(step.imageIds, <String>[pattern.images.single.id]);
      expect(files.files.keys, <String>[pattern.images.single.path]);
      expect(project.coverPath, pattern.images.single.path);
    });

    test('нет шаблона — NotFoundFailure, проекта нет', () async {
      final Result<Project> r = await create.fromTemplate(name: 'X', templateId: 'нет');
      expect(r.failureOrNull, isA<NotFoundFailure>());
      expect(alive(), isEmpty);
    });

    test('из фото: по шагу на фото, картинки обработаны и записаны, обложка — первая', () async {
      final Project project = (await create.fromPhotos(
        name: 'По фото',
        photos: <Uint8List>[
          Uint8List.fromList(<int>[1]),
          Uint8List.fromList(<int>[2]),
        ],
      )).valueOrNull!;

      final StepPattern pattern = patterns.byProject[project.id]!;
      final List<InstructionStep> steps = pattern.sections.single.steps;
      expect(steps, hasLength(2));
      expect(steps.map((s) => s.imageIds.single), pattern.images.map((i) => i.id));
      expect(files.files, hasLength(2));
      expect(processor.calls, hasLength(2));
      expect(project.coverPath, pattern.images.first.path);
    });

    test('без фото — ValidationFailure', () async {
      expect((await create.fromPhotos(name: 'X', photos: <Uint8List>[])).failureOrNull, isA<ValidationFailure>());
    });

    test('сбой записи файла не оставляет ни проекта, ни файлов', () async {
      files.failWritesAfter = 1;
      final Result<Project> r = await create.fromPhotos(
        name: 'X',
        photos: <Uint8List>[
          Uint8List.fromList(<int>[1]),
          Uint8List.fromList(<int>[2]),
        ],
      );
      expect(r.isFailure, isTrue);
      expect(alive(), isEmpty);
      expect(files.files, isEmpty);
    });

    test('сбой сохранения инструкции откатывает проект и файлы', () async {
      patterns.failNextSave = const StorageFailure('диск');
      final Result<Project> r = await create.fromTemplate(name: 'X', templateId: 'raw');
      expect(r.isFailure, isTrue);
      expect(alive(), isEmpty);
      expect(files.files, isEmpty);
    });
  });

  group('SaveStepPattern', () {
    test('убирает файлы картинок, на которые шаги больше не ссылаются', () async {
      final Project project = (await create.fromPhotos(
        name: 'X',
        photos: <Uint8List>[
          Uint8List.fromList(<int>[1]),
          Uint8List.fromList(<int>[2]),
        ],
      )).valueOrNull!;
      final StepPattern before = patterns.byProject[project.id]!;
      final InstructionStep first = before.sections.single.steps.first;
      final StepPattern after = before.copyWith(
        sections: <StepSection>[
          before.sections.single.copyWith(steps: <InstructionStep>[first]),
        ],
      );

      final SaveStepPattern save = SaveStepPattern(patterns: patterns, files: files);
      expect((await save(after)).isSuccess, isTrue);

      expect(patterns.byProject[project.id]!.images, <StepImage>[before.images.first]);
      expect(files.files.keys, <String>[before.images.first.path]);
    });

    test('картинка без шага в базу не попадает, а файл удаляется', () async {
      const StepImage orphan = StepImage(id: 'o', path: 'x/o.png', width: 1, height: 1);
      files.files['x/o.png'] = Uint8List(1);
      const StepPattern base = StepPattern(
        id: 'p',
        projectId: 'pr',
        sections: <StepSection>[
          StepSection(
            id: 'a',
            steps: <InstructionStep>[InstructionStep(id: 's')],
          ),
        ],
      );
      final SaveStepPattern save = SaveStepPattern(patterns: patterns, files: files);

      await save(base.copyWith(images: <StepImage>[orphan]));

      expect(patterns.byProject['pr']!.images, isEmpty);
      expect(files.files, isEmpty);
    });

    test('сбой сохранения не трогает файлы', () async {
      const StepPattern base = StepPattern(
        id: 'p',
        projectId: 'pr',
        sections: <StepSection>[
          StepSection(
            id: 'a',
            steps: <InstructionStep>[
              InstructionStep(id: 's', imageIds: <String>['i']),
            ],
          ),
        ],
        images: <StepImage>[StepImage(id: 'i', path: 'x/i.png', width: 1, height: 1)],
      );
      files.files['x/i.png'] = Uint8List(1);
      patterns.failNextSave = const StorageFailure('диск');

      expect((await SaveStepPattern(patterns: patterns, files: files)(base)).isFailure, isTrue);
      expect(files.files, hasLength(1));
    });
  });

  group('SaveStepPattern и курсор', () {
    const StepPattern base = StepPattern(
      id: 'p',
      projectId: 'pr',
      sections: <StepSection>[
        StepSection(
          id: 'a',
          steps: <InstructionStep>[
            InstructionStep(id: 's1'),
            InstructionStep(id: 's2'),
            InstructionStep(id: 's3'),
          ],
        ),
      ],
    );

    test('удаление шага под курсором сдвигает курсор на следующий', () async {
      patterns.byProject['pr'] = base;
      await progress.save('p', const StepsProgress(sectionId: 'a', sectionPass: 1, stepId: 's2', stepPass: 1));
      final StepPattern after = base.copyWith(
        sections: <StepSection>[
          base.sections.single.copyWith(
            steps: <InstructionStep>[base.sections.single.steps[0], base.sections.single.steps[2]],
          ),
        ],
      );

      await SaveStepPattern(patterns: patterns, files: files, progress: progress)(after);

      expect(progress.byPattern['p']!.stepId, 's3');
    });

    test('без сохранённого курсора запись прогресса не создаётся', () async {
      patterns.byProject['pr'] = base;
      await SaveStepPattern(patterns: patterns, files: files, progress: progress)(base);
      expect(progress.byPattern, isEmpty);
      final StepNavigation nav = StepNavigation(progress);
      await nav.reconcile(before: base, after: base);
      expect(progress.byPattern, isEmpty);
    });

    test('документ, который не прочитать (повторный id, бусина вне палитры), не сохраняется', () async {
      final SaveStepPattern save = SaveStepPattern(patterns: patterns, files: files);
      final StepPattern duplicateIds = base.copyWith(
        sections: <StepSection>[
          base.sections.single.copyWith(
            steps: const <InstructionStep>[
              InstructionStep(id: 's1'),
              InstructionStep(id: 's1'),
            ],
          ),
        ],
      );
      final StepPattern badBead = base.copyWith(
        sections: <StepSection>[
          base.sections.single.copyWith(
            steps: const <InstructionStep>[
              InstructionStep(id: 's1', beads: <StepBead>[StepBead(colorIndex: 3, count: 1)]),
            ],
          ),
        ],
      );

      expect((await save(duplicateIds)).failureOrNull, isA<ValidationFailure>());
      expect((await save(badBead)).failureOrNull, isA<ValidationFailure>());
      expect(patterns.byProject, isEmpty);
    });
  });

  group('StepNavigation', () {
    const StepPattern pattern = StepPattern(
      id: 'p',
      projectId: 'pr',
      sections: <StepSection>[
        StepSection(
          id: 'a',
          steps: <InstructionStep>[
            InstructionStep(id: 's1', repeat: Repeat.times(2)),
            InstructionStep(id: 's2'),
          ],
        ),
      ],
    );

    test('без сохранённого положения — начало; шаги сохраняются и переживают «перезапуск»', () async {
      final StepNavigation nav = StepNavigation(progress);
      expect((await nav.current(pattern)).valueOrNull, StepsProgress.start(pattern));

      await nav.next(pattern);
      final StepsProgress second = (await nav.next(pattern)).valueOrNull!;

      expect(second.stepId, 's2');
      expect((await StepNavigation(progress).current(pattern)).valueOrNull, second);
      expect((await nav.previous(pattern)).valueOrNull!.stepPass, 2);
      expect((await nav.jumpTo(pattern, 's2')).valueOrNull!.stepId, 's2');
    });
  });

  group('StepMaterials', () {
    test('бусины × повтор шага × повтор секции; «до нужной длины» считается один раз', () {
      final PatternColor c = blue();
      final StepPattern p = StepPattern(
        id: 'p',
        projectId: 'pr',
        palette: <PatternColor>[
          c,
          c.copyWith(name: 'Красный'),
        ],
        sections: const <StepSection>[
          StepSection(
            id: 'a',
            repeat: Repeat.times(3),
            steps: <InstructionStep>[
              InstructionStep(id: 's1', beads: <StepBead>[StepBead(colorIndex: 0, count: 2)], repeat: Repeat.times(4)),
              InstructionStep(id: 's2', beads: <StepBead>[StepBead(colorIndex: 0, count: 1)]),
            ],
          ),
          StepSection(
            id: 'b',
            repeat: Repeat.untilDone(),
            steps: <InstructionStep>[
              InstructionStep(id: 's3', beads: <StepBead>[StepBead(colorIndex: 1, count: 5)]),
            ],
          ),
        ],
      );

      final List<StepMaterialLine> lines = StepMaterials.of(p);

      expect(lines.map((l) => (l.colorIndex, l.pieces)), <(int, int)>[(0, 27), (1, 5)]);
    });
  });

  group('содержимое проекта', () {
    test('копия при дублировании: файлы копируются, id заново, прогресс не переносится', () async {
      final Project source = (await create.fromTemplate(name: 'RAW', templateId: 'raw')).valueOrNull!;
      final StepPattern original = patterns.byProject[source.id]!;
      await progress.save(original.id, StepsProgress.start(original));
      final DuplicateProject duplicate = DuplicateProject(
        repository: projects,
        ids: ids,
        clock: clock,
        cloners: <StepPatternContentCloner>[
          StepPatternContentCloner(patterns: patterns, projects: projects, files: files, ids: ids),
        ],
      );

      final Project copy = (await duplicate(source.id)).valueOrNull!;

      final StepPattern copied = patterns.byProject[copy.id]!;
      expect(copied.id, isNot(original.id));
      expect(copied.images.single.path, isNot(original.images.single.path));
      expect(files.files, hasLength(2));
      expect(copied.sections.single.steps.single.imageIds, <String>[copied.images.single.id]);
      expect(copied.palette, original.palette);
      expect(progress.byPattern.containsKey(copied.id), isFalse);
      expect(projects.projects[copy.id]!.coverPath, copied.images.single.path);
    });

    test('сбой копирования файла откатывает копию проекта', () async {
      final Project source = (await create.fromTemplate(name: 'RAW', templateId: 'raw')).valueOrNull!;
      files.failCopy = true;
      final DuplicateProject duplicate = DuplicateProject(
        repository: projects,
        ids: ids,
        clock: clock,
        cloners: <StepPatternContentCloner>[
          StepPatternContentCloner(patterns: patterns, projects: projects, files: files, ids: ids),
        ],
      );

      expect((await duplicate(source.id)).isFailure, isTrue);
      expect(alive(), hasLength(1));
    });

    test('удаление проекта убирает инструкцию и файлы', () async {
      final Project source = (await create.fromTemplate(name: 'RAW', templateId: 'raw')).valueOrNull!;
      final DeleteProject delete = DeleteProject(
        projects,
        cleaners: <StepPatternContentCleaner>[StepPatternContentCleaner(patterns: patterns, files: files)],
      );

      expect((await delete(source.id)).isSuccess, isTrue);

      expect(patterns.byProject, isEmpty);
      expect(files.files, isEmpty);
    });
  });

  group('превью в библиотеке', () {
    test('картинка текущего шага и доля пройденного', () async {
      final Project project = (await create.fromPhotos(
        name: 'X',
        photos: <Uint8List>[
          Uint8List.fromList(<int>[1]),
          Uint8List.fromList(<int>[2]),
        ],
      )).valueOrNull!;
      final StepPattern pattern = patterns.byProject[project.id]!;
      final LoadProjectPreview load = LoadProjectPreview(
        patterns: FakeGridPatternRepository(),
        rows: FakeGridProgressStore(),
        cells: FakeCellProgressStore(),
        files: files,
        steps: patterns,
        stepsProgress: progress,
      );

      ProjectPreview preview = await load(project);
      expect(preview.cover, Uint8List.fromList(<int>[1]));
      expect(preview.progress, 0);

      await progress.save(pattern.id, StepsProgress.start(pattern).next(pattern));
      preview = await load(project);
      expect(preview.cover, Uint8List.fromList(<int>[2]));
      expect(preview.progress, 0.5);
    });

    test('без репозитория инструкций — пустое превью', () async {
      final Project project = (await create.empty(name: 'X')).valueOrNull!;
      final LoadProjectPreview load = LoadProjectPreview(
        patterns: FakeGridPatternRepository(),
        rows: FakeGridProgressStore(),
        cells: FakeCellProgressStore(),
        files: files,
      );
      expect(await load(project), const ProjectPreview());
    });
  });
}
