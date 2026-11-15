import 'package:beading/core/failure.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/data/steps/drift_step_pattern_repository.dart';
import 'package:beading/data/steps/drift_steps_progress_store.dart';
import 'package:beading/domain/steps/repeat.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/steps_progress.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_project_repository.dart';
import '../../support/in_memory_database.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late DriftStepPatternRepository repository;
  late DriftStepsProgressStore progress;

  StepPattern pattern({List<StepImage> images = const <StepImage>[], String text = 'шаг'}) => StepPattern(
    id: 'pat',
    projectId: 'proj',
    sections: <StepSection>[
      StepSection(
        id: 'a',
        steps: <InstructionStep>[
          InstructionStep(id: 's1', text: text, imageIds: <String>[for (final StepImage i in images) i.id]),
          const InstructionStep(id: 's2', repeat: Repeat.times(4)),
        ],
      ),
    ],
    images: images,
  );

  const StepImage img1 = StepImage(id: 'i1', path: 'step_patterns/pat/i1.png', width: 10, height: 20);
  const StepImage img2 = StepImage(id: 'i2', path: 'step_patterns/pat/i2.png', width: 30, height: 40);

  setUp(() async {
    db = createInMemoryDatabase();
    clock = FakeClock(DateTime.utc(2026, 11, 15, 12));
    final DriftDeviceIdProvider devices = DriftDeviceIdProvider(
      dao: db.settingsDao,
      ids: FakeIdGenerator(),
      clock: clock,
    );
    repository = DriftStepPatternRepository(dao: db.stepPatternsDao, deviceIds: devices, clock: clock);
    progress = DriftStepsProgressStore(dao: db.stepPatternsDao, deviceIds: devices, clock: clock);
    await db.customStatement(
      'INSERT INTO projects (id, name, technique, content_kind, last_worked_at, created_at, updated_at, device_id) '
      "VALUES ('proj', 'П', 'offLoom', 'steps', 0, 1, 1, 'd')",
    );
  });

  test('нет инструкции — NotFoundFailure', () async {
    expect((await repository.getByProject('proj')).failureOrNull, isA<NotFoundFailure>());
  });

  test('сохранённая инструкция читается обратно вместе с картинками и служебными колонками', () async {
    final StepPattern original = pattern(images: <StepImage>[img1, img2]);
    expect((await repository.save(original)).isSuccess, isTrue);

    expect((await repository.getByProject('proj')).valueOrNull, original);
    final StepPatternRow row = (await db.select(db.stepPatterns).get()).single;
    expect(row.bodyVersion, 1);
    expect(row.createdAt, clock.now().millisecondsSinceEpoch);
    expect(row.deviceId, isNotEmpty);
  });

  test('повторное сохранение заменяет документ и убирает ненужные картинки надгробием', () async {
    await repository.save(pattern(images: <StepImage>[img1, img2]));
    clock.advance(const Duration(minutes: 1));
    await repository.save(pattern(images: <StepImage>[img2], text: 'новый'));

    final StepPattern read = (await repository.getByProject('proj')).valueOrNull!;
    expect(read.sections.single.steps.first.text, 'новый');
    expect(read.images, <StepImage>[img2]);
    final List<StepImageRow> rows = await db.select(db.stepImages).get();
    expect(rows, hasLength(2));
    expect(rows.singleWhere((r) => r.id == 'i1').deletedAt, isNotNull);
    expect((await db.select(db.stepPatterns).get()).single.updatedAt, clock.now().millisecondsSinceEpoch);
  });

  test('картинка, убранная и снова добавленная, оживает', () async {
    await repository.save(pattern(images: <StepImage>[img1]));
    await repository.save(pattern());
    await repository.save(pattern(images: <StepImage>[img1]));

    expect((await repository.getByProject('proj')).valueOrNull!.images, <StepImage>[img1]);
    expect(await db.select(db.stepImages).get(), hasLength(1));
  });

  test('документ новее поддерживаемого — ValidationFailure', () async {
    await repository.save(pattern());
    await db.customStatement('UPDATE step_patterns SET body = \'{"v":99}\'');
    expect((await repository.getByProject('proj')).failureOrNull, isA<ValidationFailure>());
  });

  test('сохранение — одна транзакция: сбой посреди откатывает документ', () async {
    await repository.save(pattern(text: 'старый'));
    // Картинка чужой инструкции с тем же id ломает вставку по внешнему ключу.
    final StepPattern broken = StepPattern(
      id: 'pat',
      projectId: 'proj',
      sections: pattern().sections,
      images: const <StepImage>[StepImage(id: 'i1', path: 'a', width: 1, height: 1)],
    );
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('CREATE TRIGGER boom BEFORE INSERT ON step_images BEGIN SELECT RAISE(ABORT, "x"); END');
    final result = await repository.save(broken.copyWith(sections: pattern(text: 'новый').sections));
    expect(result.isFailure, isTrue);
    expect((await repository.getByProject('proj')).valueOrNull!.sections.single.steps.first.text, 'старый');
  });

  test('удаление проекта ставит надгробие инструкции, картинкам и прогрессу', () async {
    await repository.save(pattern(images: <StepImage>[img1]));
    await progress.save('pat', const StepsProgress(sectionId: 'a', sectionPass: 1, stepId: 's2', stepPass: 3));

    expect((await repository.deleteByProject('proj')).isSuccess, isTrue);

    expect((await repository.getByProject('proj')).failureOrNull, isA<NotFoundFailure>());
    expect((await progress.load('pat')).valueOrNull, isNull);
    expect((await db.select(db.stepImages).get()).single.deletedAt, isNotNull);
    expect((await repository.deleteByProject('proj')).isSuccess, isTrue);
    expect((await repository.deleteByProject('нет')).isSuccess, isTrue);
  });

  test('прогресс: нет записи — null, потом сохраняется и обновляется той же строкой', () async {
    await repository.save(pattern());
    expect((await progress.load('pat')).valueOrNull, isNull);

    const StepsProgress first = StepsProgress(sectionId: 'a', sectionPass: 1, stepId: 's1', stepPass: 1);
    const StepsProgress second = StepsProgress(
      sectionId: 'a',
      sectionPass: 2,
      stepId: 's2',
      stepPass: 3,
      finished: true,
    );
    await progress.save('pat', first);
    expect((await progress.load('pat')).valueOrNull, first);
    clock.advance(const Duration(minutes: 1));
    await progress.save('pat', second);
    expect((await progress.load('pat')).valueOrNull, second);
    final StepProgressRow row = (await db.select(db.stepProgressRows).get()).single;
    expect(row.updatedAt, greaterThan(row.createdAt));
  });

  test('после удаления тот же id оживает, а другой id для проекта отклоняется', () async {
    await repository.save(pattern());
    await repository.deleteByProject('proj');

    final StepPattern other = StepPattern(id: 'другой', projectId: 'proj', sections: pattern().sections);
    expect((await repository.save(other)).failureOrNull, isA<ValidationFailure>());

    expect((await repository.save(pattern(text: 'снова'))).isSuccess, isTrue);
    expect((await repository.getByProject('proj')).valueOrNull!.sections.single.steps.first.text, 'снова');
  });

  test('template_id обновляется при замене, размер картинки при том же пути тоже', () async {
    await repository.save(pattern(images: <StepImage>[img1]));
    final StepPattern changed = StepPattern(
      id: 'pat',
      projectId: 'proj',
      sections: pattern(images: <StepImage>[img1]).sections,
      images: const <StepImage>[StepImage(id: 'i1', path: 'step_patterns/pat/i1.png', width: 99, height: 98)],
    );
    await repository.save(changed);

    expect((await db.select(db.stepPatterns).get()).single.templateId, isNull);
    expect((await repository.getByProject('proj')).valueOrNull!.images.single.width, 99);
  });

  test('курсор нельзя записать для удалённой инструкции', () async {
    await repository.save(pattern());
    await repository.deleteByProject('proj');
    final result = await progress.save(
      'pat',
      const StepsProgress(sectionId: 'a', sectionPass: 1, stepId: 's1', stepPass: 1),
    );
    expect(result.failureOrNull, isA<NotFoundFailure>());
  });
}
