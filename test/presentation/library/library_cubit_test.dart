import 'package:beading/core/failure.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/delete_project.dart';
import 'package:beading/domain/projects/use_cases/duplicate_project.dart';
import 'package:beading/domain/projects/use_cases/rename_project.dart';
import 'package:beading/domain/projects/use_cases/watch_projects.dart';
import 'package:beading/presentation/library/library_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_project_repository.dart';

Project project(
  String id,
  String name, {
  Craft craft = Craft.beading,
  ProjectStatus status = ProjectStatus.idea,
  int day = 1,
}) => Project(
  id: id,
  name: name,
  status: status,
  craft: craft,
  technique: Technique.defaultFor(craft),
  contentKind: ContentKind.image,
  notes: '',
  coverPath: null,
  lastWorkedAt: DateTime.utc(2026, 1, day),
);

void main() {
  late FakeProjectRepository repository;

  LibraryCubit createCubit() => LibraryCubit(
    watchProjects: WatchProjects(repository),
    deleteProject: DeleteProject(repository),
    renameProject: RenameProject(repository),
    duplicateProject: DuplicateProject(
      repository: repository,
      ids: FakeIdGenerator(),
      clock: FakeClock(DateTime.utc(2026, 2)),
    ),
  );

  setUp(() {
    repository = FakeProjectRepository();
  });

  test('до первого ответа хранилища идёт загрузка', () {
    final LibraryCubit cubit = createCubit();
    addTearDown(cubit.close);

    expect(cubit.state.status, LibraryStatus.loading);
  });

  test('после start показывает проекты, недавние первыми', () async {
    repository.projects['a'] = project('a', 'Старый');
    repository.projects['b'] = project('b', 'Новый', day: 5);
    final LibraryCubit cubit = createCubit();
    addTearDown(cubit.close);

    cubit.start();
    await pumpEventQueue();

    expect(cubit.state.status, LibraryStatus.ready);
    expect(cubit.state.visible.map((p) => p.name), <String>['Новый', 'Старый']);
    expect(cubit.state.hasProjects, isTrue);
  });

  test('пустая библиотека: проектов нет и это не «нет совпадений»', () async {
    final LibraryCubit cubit = createCubit();
    addTearDown(cubit.close);

    cubit.start();
    await pumpEventQueue();

    expect(cubit.state.hasProjects, isFalse);
    expect(cubit.state.hasNoMatches, isFalse);
  });

  group('последовательность состояний', () {
    blocTest<LibraryCubit, LibraryState>(
      'загрузка: проекты приходят одним состоянием ready',
      setUp: () => repository.projects['a'] = project('a', 'Браслет'),
      build: createCubit,
      act: (cubit) => cubit.start(),
      wait: Duration.zero,
      expect: () => <Matcher>[
        isA<LibraryState>().having((s) => s.status, 'status', LibraryStatus.ready).having(
          (s) => s.projects.map((p) => p.id),
          'ids',
          <String>['a'],
        ),
      ],
    );

    blocTest<LibraryCubit, LibraryState>(
      'поиск и фильтр дают отдельные состояния с обновлённым фильтром',
      setUp: () => repository.projects['a'] = project('a', 'Браслет'),
      build: createCubit,
      seed: () => LibraryState(status: LibraryStatus.ready, projects: <Project>[project('a', 'Браслет')]),
      act: (cubit) => cubit
        ..setQuery('бр')
        ..toggleCraft(Craft.beading),
      expect: () => <Matcher>[
        isA<LibraryState>().having((s) => s.filter.query, 'query', 'бр'),
        isA<LibraryState>()
            .having((s) => s.filter.query, 'query', 'бр')
            .having((s) => s.filter.craft, 'craft', Craft.beading),
      ],
    );
  });

  test('действие, завершившееся после close, не падает', () async {
    repository.projects['a'] = project('a', 'Браслет');
    final LibraryCubit cubit = createCubit();
    cubit.start();
    await pumpEventQueue();

    final Future<void> pending = cubit.delete('нет-такого');
    await cubit.close();

    await expectLater(pending, completes);
  });

  group('фильтры', () {
    setUp(() {
      repository.projects['a'] = project('a', 'Браслет Ёлка', day: 3);
      repository.projects['b'] = project('b', 'Салфетка', craft: Craft.crossStitch, day: 2);
      repository.projects['c'] = project('c', 'Серьги', status: ProjectStatus.done);
    });

    Future<LibraryCubit> started() async {
      final LibraryCubit cubit = createCubit();
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();
      return cubit;
    }

    test('поиск без учёта регистра и ё/е', () async {
      final LibraryCubit cubit = await started();

      cubit.setQuery('ЕЛКА');

      expect(cubit.state.visible.map((p) => p.id), <String>['a']);
    });

    test('фильтр по ремеслу; повторное нажатие снимает его', () async {
      final LibraryCubit cubit = await started();

      cubit.toggleCraft(Craft.crossStitch);
      expect(cubit.state.visible.map((p) => p.id), <String>['b']);

      cubit.toggleCraft(Craft.crossStitch);
      expect(cubit.state.visible, hasLength(3));
    });

    test('фильтр по статусу сочетается с ремеслом', () async {
      final LibraryCubit cubit = await started();

      cubit.toggleStatus(ProjectStatus.done);
      expect(cubit.state.visible.map((p) => p.id), <String>['c']);

      cubit.toggleCraft(Craft.crossStitch);
      expect(cubit.state.visible, isEmpty);
      expect(cubit.state.hasNoMatches, isTrue);
      expect(cubit.state.hasProjects, isTrue);
    });

    test('clearFilters возвращает все проекты', () async {
      final LibraryCubit cubit = await started();
      cubit
        ..setQuery('ничего')
        ..toggleCraft(Craft.beading);

      cubit.clearFilters();

      expect(cubit.state.visible, hasLength(3));
      expect(cubit.state.filter.query, isEmpty);
      expect(cubit.state.hasActiveFilter, isFalse);
    });

    test('смена выбранного статуса заменяет прежний', () async {
      final LibraryCubit cubit = await started();

      cubit
        ..toggleStatus(ProjectStatus.done)
        ..toggleStatus(ProjectStatus.idea);

      expect(cubit.state.filter.status, ProjectStatus.idea);
    });
  });

  group('действия', () {
    blocTest<LibraryCubit, LibraryState>(
      'удаление убирает проект из списка',
      setUp: () => repository.projects['a'] = project('a', 'Браслет'),
      build: createCubit,
      act: (cubit) async {
        cubit.start();
        await pumpEventQueue();
        await cubit.delete('a');
      },
      verify: (cubit) {
        expect(repository.deleted, contains('a'));
        expect(cubit.state.visible, isEmpty);
      },
    );

    test('ошибка удаления попадает в actionFailure и сбрасывается', () async {
      final LibraryCubit cubit = createCubit();
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();

      await cubit.delete('нет-такого');
      expect(cubit.state.actionFailure, isA<NotFoundFailure>());

      cubit.acknowledgeActionFailure();
      expect(cubit.state.actionFailure, isNull);
    });

    test('переименование меняет название', () async {
      repository.projects['a'] = project('a', 'Браслет');
      final LibraryCubit cubit = createCubit();
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();

      await cubit.rename('a', '  Колье ');

      expect(repository.projects['a']!.name, 'Колье');
      expect(cubit.state.actionFailure, isNull);
    });

    test('пустое название при переименовании — ошибка проверки, название прежнее', () async {
      repository.projects['a'] = project('a', 'Браслет');
      final LibraryCubit cubit = createCubit();
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();

      await cubit.rename('a', '   ');

      expect(cubit.state.actionFailure, isA<ValidationFailure>());
      expect(repository.projects['a']!.name, 'Браслет');
    });

    test('дублирование добавляет копию', () async {
      repository.projects['a'] = project('a', 'Браслет');
      final LibraryCubit cubit = createCubit();
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();

      await cubit.duplicate('a');
      await pumpEventQueue();

      expect(cubit.state.visible.map((p) => p.name), containsAll(<String>['Браслет', 'Браслет (копия)']));
    });

    test('ошибка дублирования попадает в actionFailure', () async {
      final LibraryCubit cubit = createCubit();
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();

      await cubit.duplicate('нет-такого');

      expect(cubit.state.actionFailure, isA<NotFoundFailure>());
    });
  });

  group('ошибки потока', () {
    test('ошибка хранилища даёт состояние failure, retry перезапускает', () async {
      final FailingOnceRepository failing = FailingOnceRepository();
      final LibraryCubit cubit = LibraryCubit(
        watchProjects: WatchProjects(failing),
        deleteProject: DeleteProject(failing),
        renameProject: RenameProject(failing),
        duplicateProject: DuplicateProject(
          repository: failing,
          ids: FakeIdGenerator(),
          clock: FakeClock(DateTime.utc(2026)),
        ),
      );
      addTearDown(cubit.close);

      cubit.start();
      await pumpEventQueue();
      expect(cubit.state.status, LibraryStatus.failure);

      cubit.retry();
      await pumpEventQueue();
      expect(cubit.state.status, LibraryStatus.ready);
    });
  });
}

/// Первый поток падает, второй работает.
class FailingOnceRepository extends FakeProjectRepository {
  bool _failed = false;

  @override
  Stream<List<Project>> watchAll() {
    if (!_failed) {
      _failed = true;
      return Stream<List<Project>>.error(const StorageFailure('диск'));
    }
    return super.watchAll();
  }
}
