import 'dart:io';
import 'dart:typed_data';

import 'package:beading/core/id_generator.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/grid_pattern/drift_cell_progress_store.dart';
import 'package:beading/data/grid_pattern/drift_grid_pattern_repository.dart';
import 'package:beading/data/grid_pattern/drift_grid_progress_store.dart';
import 'package:beading/data/image_pattern/drift_book_work_repository.dart';
import 'package:beading/data/image_pattern/drift_image_pattern_repository.dart';
import 'package:beading/data/image_pattern/local_file_store.dart';
import 'package:beading/data/projects/drift_project_repository.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/data/sharing/drift_unit_of_work.dart';
import 'package:beading/data/sharing/zip_biser_codec.dart';
import 'package:beading/data/weaving/drift_work_session_repository.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/settings/app_info.dart';
import 'package:beading/domain/sharing/biser/export_projects.dart';
import 'package:beading/domain/sharing/biser/import_biser.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import 'fake_clock.dart';
import 'in_memory_database.dart';

class _AppInfo implements AppInfoProvider {
  @override
  Future<AppInfo> load() async => const AppInfo(version: '0.1.0', build: '1');
}

/// «Устройство»: настоящая база в памяти, настоящие репозитории и каталог файлов во временной папке.
class BiserDevice {
  BiserDevice({FileStore Function(FileStore real)? wrapFiles}) {
    // Два «устройства» в одном тесте — две базы в памяти, они не делят исполнитель.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = createInMemoryDatabase();
    root = Directory.systemTemp.createTempSync('biser_device');
    addTearDown(() => root.deleteSync(recursive: true));
    clock = FakeClock(DateTime.utc(2026, 11, 10, 12));
    ids = UuidV7IdGenerator(clock: clock);
    final DriftDeviceIdProvider devices = DriftDeviceIdProvider(dao: db.settingsDao, ids: ids, clock: clock);
    projects = DriftProjectRepository(dao: db.projectsDao, deviceIds: devices, clock: clock);
    grids = DriftGridPatternRepository(dao: db.gridPatternsDao, deviceIds: devices, clock: clock, ids: ids);
    progress = DriftGridProgressStore(dao: db.gridPatternsDao, deviceIds: devices, clock: clock, ids: ids);
    cellProgress = DriftCellProgressStore(dao: db.gridPatternsDao, deviceIds: devices, clock: clock, ids: ids);
    images = DriftImagePatternRepository(dao: db.imagePatternsDao, deviceIds: devices, clock: clock);
    bookWork = DriftBookWorkRepository(dao: db.bookWorkDao, deviceIds: devices, clock: clock);
    workSessions = DriftWorkSessionRepository(dao: db.workSessionsDao, deviceIds: devices, clock: clock, ids: ids);
    final LocalFileStore real = LocalFileStore(() async => root);
    realFiles = real;
    files = wrapFiles == null ? real : wrapFiles(real);
    export = ExportProjects(
      projects: projects,
      grids: grids,
      progress: progress,
      cellProgress: cellProgress,
      images: images,
      bookWork: bookWork,
      workSessions: workSessions,
      files: files,
      codec: const ZipBiserCodec(),
      clock: clock,
      appInfo: _AppInfo(),
    );
    import = ImportBiser(
      codec: const ZipBiserCodec(),
      projects: projects,
      grids: grids,
      progress: progress,
      cellProgress: cellProgress,
      images: images,
      bookWork: bookWork,
      workSessions: workSessions,
      files: files,
      ids: ids,
      unitOfWork: DriftUnitOfWork(db),
    );
  }

  late final AppDatabase db;
  late final Directory root;
  late final FakeClock clock;
  late final UuidV7IdGenerator ids;
  late final DriftProjectRepository projects;
  late final DriftGridPatternRepository grids;
  late final DriftGridProgressStore progress;
  late final DriftCellProgressStore cellProgress;
  late final DriftImagePatternRepository images;
  late final DriftBookWorkRepository bookWork;
  late final DriftWorkSessionRepository workSessions;
  late final FileStore files;
  late final LocalFileStore realFiles;
  late final ExportProjects export;
  late final ImportBiser import;

  List<File> filesOnDisk() => root.existsSync() ? root.listSync(recursive: true).whereType<File>().toList() : <File>[];

  Future<List<Project>> allProjects() => projects.watchAll().first;

  /// Резервная копия без поля `exportedAt`: так сравнивают содержимое двух устройств.
  Future<Uint8List> backupBytes() async => (await export.backup()).valueOrNull!.bytes;
}

/// Простое проектное значение для тестов.
Project sampleProject(String id, {ContentKind kind = ContentKind.grid, String name = 'Проект', String? cover}) =>
    Project(
      id: id,
      name: name,
      status: ProjectStatus.inProgress,
      craft: Craft.beading,
      technique: Technique.peyote,
      contentKind: kind,
      notes: 'Заметки',
      coverPath: cover,
      lastWorkedAt: DateTime.utc(2026, 11, 9, 8, 30),
    );
