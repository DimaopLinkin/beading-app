import 'dart:io';

import 'package:beading/core/id_generator.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/image_pattern/drift_image_pattern_repository.dart';
import 'package:beading/data/image_pattern/local_file_store.dart';
import 'package:beading/data/image_pattern/ui_image_processor.dart';
import 'package:beading/data/projects/drift_project_repository.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';
import 'package:beading/domain/image_pattern/image_pattern_content.dart';
import 'package:beading/domain/image_pattern/use_cases/import_book_pattern.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/projects/use_cases/delete_project.dart';
import 'package:beading/domain/projects/use_cases/duplicate_project.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/in_memory_database.dart';
import '../../support/test_images.dart';

/// Сквозной сценарий на настоящих базе, файлах и картинках: импорт → копия → удаление.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('файлы страниц живут и умирают вместе с проектом', () async {
    final AppDatabase db = createInMemoryDatabase();
    final Directory root = Directory.systemTemp.createTempSync('book_flow');
    addTearDown(() => root.deleteSync(recursive: true));
    final FakeClock clock = FakeClock(DateTime.utc(2026, 11, 9));
    final UuidV7IdGenerator ids = UuidV7IdGenerator(clock: clock);
    final DriftDeviceIdProvider deviceIds = DriftDeviceIdProvider(dao: db.settingsDao, ids: ids, clock: clock);
    final DriftProjectRepository projects = DriftProjectRepository(
      dao: db.projectsDao,
      deviceIds: deviceIds,
      clock: clock,
    );
    final DriftImagePatternRepository patterns = DriftImagePatternRepository(
      dao: db.imagePatternsDao,
      deviceIds: deviceIds,
      clock: clock,
    );
    final LocalFileStore files = LocalFileStore(() async => root);
    final ImportBookPattern import = ImportBookPattern(
      createProject: CreateProject(repository: projects, ids: ids, clock: clock),
      projects: projects,
      patterns: patterns,
      processor: const UiImageProcessor(),
      files: files,
      ids: ids,
    );
    final ImagePatternContentCloner cloner = ImagePatternContentCloner(
      patterns: patterns,
      projects: projects,
      files: files,
      ids: ids,
    );
    final ImagePatternContentCleaner cleaner = ImagePatternContentCleaner(patterns: patterns, files: files);
    List<File> onDisk() => root.listSync(recursive: true).whereType<File>().toList();

    final Project project = (await import(
      name: 'Роза',
      pages: <BookPageSource>[
        BookPageSource(bytes: await redBluePng()),
        BookPageSource(bytes: await redBluePng()),
      ],
    )).valueOrNull!;
    expect(onDisk(), hasLength(2));
    expect(File('${root.path}/${project.coverPath}').existsSync(), isTrue);

    final Project copy = (await DuplicateProject(
      repository: projects,
      ids: ids,
      clock: clock,
      cloners: <ImagePatternContentCloner>[cloner],
    )(project.id)).valueOrNull!;
    expect(onDisk(), hasLength(4));

    await DeleteProject(projects, cleaners: <ImagePatternContentCleaner>[cleaner])(project.id);
    expect(onDisk(), hasLength(2));
    final ImagePattern left = (await patterns.getByProject(copy.id)).valueOrNull!;
    expect(onDisk().map((f) => f.path), everyElement(startsWith('${root.path}/book_patterns/')));
    expect(left.pages.every((p) => File('${root.path}/${p.path}').existsSync()), isTrue);
  });
}
