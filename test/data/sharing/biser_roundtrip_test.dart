import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/sharing/zip_biser_codec.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/sharing/biser/biser_models.dart';
import 'package:beading/domain/sharing/biser/import_biser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/biser_device.dart';
import '../../support/biser_samples.dart';

/// Кладёт в «устройство» набор проектов через настоящие репозитории.
Future<void> populate(BiserDevice device, BiserBundle bundle) async {
  for (final BiserProject item in bundle.projects) {
    final String? cover = item.coverPageId == null
        ? null
        : 'book_patterns/${item.book!.patternId}/${item.coverPageId}.png';
    await device.projects.save(
      Project(
        id: item.project.id,
        name: item.project.name,
        status: item.project.status,
        craft: item.project.craft,
        technique: item.project.technique,
        contentKind: item.project.contentKind,
        notes: item.project.notes,
        coverPath: cover,
        lastWorkedAt: item.project.lastWorkedAt,
      ),
    );
    if (item.grid != null) {
      await device.grids.save(item.grid!);
      for (final int row in item.progress!.completedRows) {
        await device.progress.markRow(item.grid!.id, row);
      }
      if (item.progress!.currentRow != null) {
        await device.progress.setCurrent(item.grid!.id, row: item.progress!.currentRow!);
      }
    }
    final BiserBook? book = item.book;
    if (book != null) {
      final List<ImagePatternPage> pages = <ImagePatternPage>[];
      for (final BiserPage page in book.pages) {
        final String path = 'book_patterns/${book.patternId}/${page.id}.png';
        await device.realFiles.write(path, bundle.files[page.file]!);
        pages.add(ImagePatternPage(id: page.id, path: path, width: page.width, height: page.height));
      }
      await device.images.save(ImagePattern(id: book.patternId, projectId: item.project.id, pages: pages));
      for (final BiserPage page in book.pages) {
        if (page.work != null) await device.bookWork.savePage(page.work!);
      }
      if (book.currentPageId != null) {
        await device.bookWork.saveCurrentPage(patternId: book.patternId, pageId: book.currentPageId!);
      }
    }
  }
}

/// Содержимое резервной копии без времени экспорта: распаковываем и сравниваем модель.
BiserBundle contentOf(Uint8List bytes) => const ZipBiserCodec().decode(bytes).valueOrNull!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('round-trip: резервная копия → пустое устройство → такая же резервная копия (20 наборов)', () async {
    for (int seed = 0; seed < 20; seed++) {
      final BiserDevice a = BiserDevice();
      final BiserDevice b = BiserDevice();
      await populate(a, randomBundle(seed, projects: 1 + seed % 4));
      final Uint8List exported = await a.backupBytes();

      final Result<ImportResult> imported = await b.import(exported);
      expect(imported.failureOrNull, isNull, reason: 'seed $seed');
      expect(imported.valueOrNull!.importedIds, hasLength(1 + seed % 4));

      final BiserBundle first = contentOf(exported);
      final BiserBundle second = contentOf(await b.backupBytes());
      expect(second.projects.toSet(), first.projects.toSet(), reason: 'seed $seed');
      expect(second.files, first.files, reason: 'seed $seed');
    }
  });

  test('один проект: экспорт даёт имя файла из названия и только этот проект', () async {
    final BiserDevice a = BiserDevice();
    await populate(a, randomBundle(3, projects: 3));
    final String id = (await a.allProjects()).first.id;
    final export = (await a.export.project(id)).valueOrNull!;
    expect(export.fileName, endsWith('.biser'));
    expect(export.projectCount, 1);
    expect(contentOf(export.bytes).kind, BiserKind.project);
  });

  test('совпавший id: «как новый» добавляет копию, существующий не трогает', () async {
    final BiserDevice a = BiserDevice();
    await populate(a, randomBundle(5, projects: 2));
    final Uint8List bytes = await a.backupBytes();
    final List<Project> before = await a.allProjects();

    final BiserPreview preview = (await a.import.preview(bytes)).valueOrNull!;
    expect(preview.conflictCount, 2);

    final ImportResult result = (await a.import(bytes)).valueOrNull!;
    expect(result.importedIds, hasLength(2));
    expect(result.importedIds.toSet().intersection(before.map((p) => p.id).toSet()), isEmpty);
    final List<Project> after = await a.allProjects();
    expect(after, hasLength(4));
    for (final Project p in before) {
      expect(after.where((x) => x.id == p.id), hasLength(1));
    }
    // Копии получили свои файлы страниц: файлов вдвое больше.
    final int pages = contentOf(bytes).files.length;
    expect(a.filesOnDisk(), hasLength(pages * 2));
  });

  test('совпавший id: «пропустить» ничего не добавляет', () async {
    final BiserDevice a = BiserDevice();
    await populate(a, randomBundle(5, projects: 2));
    final Uint8List bytes = await a.backupBytes();
    final ImportResult result = (await a.import(bytes, defaultChoice: ConflictChoice.skip)).valueOrNull!;
    expect(result.importedIds, isEmpty);
    expect(result.skipped, 2);
    expect(await a.allProjects(), hasLength(2));
  });

  test('чужая схема или страница с тем же id не перезаписывается: импорт берёт новые id', () async {
    final BiserDevice source = BiserDevice();
    BiserBundle bundle = randomBundle(0, projects: 1);
    for (int seed = 1; bundle.projects.first.book == null; seed++) {
      bundle = randomBundle(seed, projects: 1);
    }
    await populate(source, bundle);
    final Uint8List bytes = await source.backupBytes();

    final BiserDevice target = BiserDevice();
    // На устройстве чужой проект с другим id, но теми же id книги и страниц, что в файле.
    final BiserProject original = bundle.projects.first;
    final BiserProject foreign = BiserProject(
      project: sampleProject('other-project', kind: ContentKind.image),
      book: original.book,
    );
    await populate(
      target,
      BiserBundle(
        kind: bundle.kind,
        exportedAt: bundle.exportedAt,
        appVersion: '0',
        projects: <BiserProject>[foreign],
        files: bundle.files,
      ),
    );
    final before = (await target.images.getByProject('other-project')).valueOrNull!;

    final ImportResult result = (await target.import(bytes)).valueOrNull!;
    expect(result.importedIds, hasLength(1));
    expect(result.importedIds.single, isNot('other-project'));
    final after = (await target.images.getByProject('other-project')).valueOrNull!;
    expect(after, before);
  });

  test('проект, удалённый раньше, возвращается копией с новым id', () async {
    final BiserDevice a = BiserDevice();
    await populate(a, randomBundle(9, projects: 1));
    final Uint8List bytes = await a.backupBytes();
    final String id = (await a.allProjects()).single.id;
    await a.projects.delete(id);

    final ImportResult result = (await a.import(bytes)).valueOrNull!;
    expect(result.importedIds.single, isNot(id));
    expect(await a.allProjects(), hasLength(1));
  });

  group('повреждённый файл не портит базу', () {
    test('не zip', () async {
      final BiserDevice a = BiserDevice();
      await populate(a, randomBundle(1));
      final Uint8List before = await a.backupBytes();
      final Result<ImportResult> result = await a.import(Uint8List.fromList(<int>[1, 2, 3, 4, 5]));
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(contentOf(await a.backupBytes()).projects, contentOf(before).projects);
    });

    test('обрезанный zip', () async {
      final BiserDevice a = BiserDevice();
      final BiserDevice b = BiserDevice();
      await populate(a, randomBundle(2, projects: 3));
      final Uint8List bytes = await a.backupBytes();
      final Result<ImportResult> result = await b.import(Uint8List.sublistView(bytes, 0, bytes.length ~/ 2));
      expect(result.isFailure, isTrue);
      expect(await b.allProjects(), isEmpty);
      expect(b.filesOnDisk(), isEmpty);
    });

    test('сбой записи файла на третьем проекте откатывает всё: ни проектов, ни схем, ни файлов', () async {
      final BiserDevice a = BiserDevice();
      // Набор, где точно есть страницы: подбираем seed, в котором не меньше двух файлов.
      BiserBundle bundle = randomBundle(0, projects: 6);
      for (int seed = 1; bundle.files.length < 3; seed++) {
        bundle = randomBundle(seed, projects: 6);
      }
      await populate(a, bundle);
      final Uint8List bytes = await a.backupBytes();

      final FailingFiles failing = FailingFiles();
      final BiserDevice b = BiserDevice(wrapFiles: (real) => failing..inner = real);
      failing.failAfter = 2;
      final Result<ImportResult> result = await b.import(bytes);

      expect(result.failureOrNull, isA<StorageFailure>());
      expect(await b.allProjects(), isEmpty);
      expect((await b.grids.getByProject(bundle.projects.first.project.id)).isFailure, isTrue);
      expect(b.filesOnDisk(), isEmpty);
    });
  });

  test('импорт не делает проект общим: проверка, что прогресс и «где остановилась» доехали', () async {
    final BiserDevice a = BiserDevice();
    final BiserDevice b = BiserDevice();
    BiserBundle bundle = randomBundle(0, projects: 1);
    for (
      int seed = 1;
      bundle.projects.first.grid == null || bundle.projects.first.progress!.completedRows.isEmpty;
      seed++
    ) {
      bundle = randomBundle(seed, projects: 1);
    }
    await populate(a, bundle);
    await b.import(await a.backupBytes());
    final GridPattern grid = (await b.grids.getByProject(bundle.projects.first.project.id)).valueOrNull!;
    final GridProgress progress = (await b.progress.load(grid.id)).valueOrNull!;
    expect(progress.completedRows, bundle.projects.first.progress!.completedRows);
    expect(grid, bundle.projects.first.grid);
  });
}

/// Файловое хранилище, которое начинает отказывать записи после [failAfter] успешных.
class FailingFiles implements FileStore {
  late FileStore inner;
  int failAfter = 1 << 30;
  int _writes = 0;

  @override
  Future<Result<Uint8List>> read(String relativePath) => inner.read(relativePath);

  @override
  Future<Result<void>> write(String relativePath, Uint8List bytes) async {
    if (_writes++ >= failAfter) {
      return const Err<void>(StorageFailure('диск полон'));
    }
    return inner.write(relativePath, bytes);
  }

  @override
  Future<Result<void>> copy({required String from, required String to}) => inner.copy(from: from, to: to);

  @override
  Future<Result<void>> delete(String relativePath) => inner.delete(relativePath);
}
