import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';
import 'package:beading/domain/image_pattern/image_pattern_content.dart';
import 'package:beading/domain/image_pattern/use_cases/import_book_pattern.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/delete_project.dart';
import 'package:beading/domain/projects/use_cases/duplicate_project.dart';
import 'package:beading/domain/projects/use_cases/watch_projects.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_image_pattern.dart';
import '../../support/fake_project_repository.dart';

void main() {
  late FakeProjectRepository projects;
  late FakeImagePatternRepository patterns;
  late FakeFileStore files;
  late FakeImageProcessor processor;
  late FakeIdGenerator ids;
  late FakeClock clock;
  late ImportBookPattern import;

  BookPageSource page(int marker, {int turns = 0, CropRect crop = CropRect.full}) =>
      BookPageSource(bytes: Uint8List.fromList(<int>[marker]), quarterTurns: turns, crop: crop);

  setUp(() {
    projects = FakeProjectRepository();
    patterns = FakeImagePatternRepository();
    files = FakeFileStore();
    processor = FakeImageProcessor();
    ids = FakeIdGenerator();
    clock = FakeClock(DateTime.utc(2026, 11, 9));
    import = ImportBookPattern(
      createProject: CreateProject(repository: projects, ids: ids, clock: clock),
      projects: projects,
      patterns: patterns,
      processor: processor,
      files: files,
      ids: ids,
    );
  });

  group('ImportBookPattern', () {
    test('создаёт проект-картинку, кладёт страницы по порядку и ставит обложку', () async {
      final Result<Project> result = await import(name: ' Браслет ', pages: <BookPageSource>[page(1), page(2)]);

      final Project project = result.valueOrNull!;
      expect(project.name, 'Браслет');
      expect(project.contentKind, ContentKind.image);
      expect(project.craft, Craft.beading);
      expect(project.status, ProjectStatus.idea);
      final ImagePattern pattern = patterns.byProject[project.id]!;
      expect(pattern.pages, hasLength(2));
      expect(files.files[pattern.pages[0].path], <int>[1]);
      expect(files.files[pattern.pages[1].path], <int>[2]);
      expect(pattern.pages[0].path, isNot(startsWith('/')));
      expect(pattern.pages[0].width, 100);
      expect(project.coverPath, pattern.pages.first.path);
      expect((await projects.get(project.id)).valueOrNull!.coverPath, pattern.pages.first.path);
    });

    test('передаёт повороты и обрезку каждой страницы в обработку', () async {
      const CropRect crop = CropRect(left: 0.1, top: 0.1, right: 0.9, bottom: 0.9);
      await import(
        name: 'Х',
        pages: <BookPageSource>[
          page(1, turns: 1),
          page(2, crop: crop),
        ],
      );

      expect(processor.calls.map((c) => c.quarterTurns), <int>[1, 0]);
      expect(processor.calls.map((c) => c.crop), <CropRect>[CropRect.full, crop]);
    });

    test('вышивка: проект выбранного ремесла с подходящей техникой', () async {
      final Project project = (await import(
        name: 'Роза',
        craft: Craft.crossStitch,
        pages: <BookPageSource>[page(1)],
      )).valueOrNull!;

      expect(project.craft, Craft.crossStitch);
      expect(project.technique, Technique.crossStitch);
    });

    test('без страниц — ValidationFailure, ничего не создано', () async {
      final Result<Project> result = await import(name: 'Х', pages: const <BookPageSource>[]);

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(projects.projects, isEmpty);
    });

    test('пустое название — Failure, файлы не остаются', () async {
      final Result<Project> result = await import(name: '  ', pages: <BookPageSource>[page(1)]);

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(files.files, isEmpty);
      expect(patterns.byProject, isEmpty);
    });

    test('ошибка обработки картинки — ничего не создано и не записано', () async {
      processor.failure = const UnexpectedFailure('битый файл');

      final Result<Project> result = await import(name: 'Х', pages: <BookPageSource>[page(1)]);

      expect(result.failureOrNull, isA<UnexpectedFailure>());
      expect(files.files, isEmpty);
      expect(projects.projects, isEmpty);
    });

    test('сбой записи второй страницы убирает первую', () async {
      files.failWritesAfter = 1;

      final Result<Project> result = await import(name: 'Х', pages: <BookPageSource>[page(1), page(2)]);

      expect(result.failureOrNull, isA<StorageFailure>());
      expect(files.files, isEmpty);
      expect(projects.projects, isEmpty);
    });

    test('сбой записи схемы откатывает проект и файлы', () async {
      patterns.failNextSave = const StorageFailure('БД');

      final Result<Project> result = await import(name: 'Х', pages: <BookPageSource>[page(1)]);

      expect(result.failureOrNull, isA<StorageFailure>());
      expect(files.files, isEmpty);
      expect(await WatchProjects(projects)().first, isEmpty);
    });
  });

  group('дублирование и удаление проекта-картинки', () {
    late ImagePatternContentCloner cloner;
    late ImagePatternContentCleaner cleaner;

    setUp(() {
      cloner = ImagePatternContentCloner(patterns: patterns, projects: projects, files: files, ids: ids);
      cleaner = ImagePatternContentCleaner(patterns: patterns, files: files);
    });

    Future<Project> imported() async =>
        (await import(name: 'Роза', pages: <BookPageSource>[page(1), page(2)])).valueOrNull!;

    test('копия получает свои файлы страниц и обложку, оригинал не тронут', () async {
      final Project source = await imported();
      final DuplicateProject duplicate = DuplicateProject(
        repository: projects,
        ids: ids,
        clock: clock,
        cloners: <ImagePatternContentCloner>[cloner],
      );

      final Project copy = (await duplicate(source.id)).valueOrNull!;

      final ImagePattern original = patterns.byProject[source.id]!;
      final ImagePattern cloned = patterns.byProject[copy.id]!;
      expect(cloned.pages, hasLength(2));
      expect(cloned.pages.map((p) => p.path).toSet().intersection(original.pages.map((p) => p.path).toSet()), isEmpty);
      expect(files.files[cloned.pages[1].path], <int>[2]);
      expect(files.files, hasLength(4));
      expect((await projects.get(copy.id)).valueOrNull!.coverPath, cloned.pages.first.path);
      expect(patterns.byProject[source.id], original);
    });

    test('сбой копирования файла откатывает копию и скопированное', () async {
      final Project source = await imported();
      final DuplicateProject duplicate = DuplicateProject(
        repository: projects,
        ids: ids,
        clock: clock,
        cloners: <ImagePatternContentCloner>[cloner],
      );
      files.failCopy = true;

      final Result<Project> result = await duplicate(source.id);

      expect(result.failureOrNull, isA<StorageFailure>());
      expect(files.files, hasLength(2));
      expect((await WatchProjects(projects)().first).map((p) => p.id), <String>[source.id]);
    });

    test('сбой записи схемы копии убирает скопированные файлы', () async {
      final Project source = await imported();
      patterns.failNextSave = const StorageFailure('БД');

      final Result<void> result = await cloner.clone(source: source, targetId: 'copy');

      expect(result.failureOrNull, isA<StorageFailure>());
      expect(files.files, hasLength(2));
    });

    test('у проекта без схемы нечего копировать и нечего убирать', () async {
      final Project empty = (await CreateProject(repository: projects, ids: ids, clock: clock)(
        name: 'Пусто',
      )).valueOrNull!;

      expect((await cloner.clone(source: empty, targetId: 'x')).isSuccess, isTrue);
      expect((await cleaner.remove(empty)).isSuccess, isTrue);
    });

    test('удаление проекта убирает файлы страниц и схему', () async {
      final Project source = await imported();

      final Result<void> result = await DeleteProject(projects, cleaners: <ImagePatternContentCleaner>[cleaner])(
        source.id,
      );

      expect(result.isSuccess, isTrue);
      expect(files.files, isEmpty);
      expect(patterns.byProject, isEmpty);
      expect(await WatchProjects(projects)().first, isEmpty);
    });

    test('копия живёт после удаления оригинала', () async {
      final Project source = await imported();
      final Project copy = (await DuplicateProject(
        repository: projects,
        ids: ids,
        clock: clock,
        cloners: <ImagePatternContentCloner>[cloner],
      )(source.id)).valueOrNull!;

      await DeleteProject(projects, cleaners: <ImagePatternContentCleaner>[cleaner])(source.id);

      expect(files.files, hasLength(2));
      expect(patterns.byProject[copy.id]!.pages, hasLength(2));
    });

    test('удаление неизвестного проекта — NotFoundFailure', () async {
      expect(
        (await DeleteProject(projects, cleaners: <ImagePatternContentCleaner>[cleaner])('нет')).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });
  });
}
