import 'dart:typed_data';

import 'package:beading/core/clock.dart';
import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/sharing/zip_biser_codec.dart';
import 'package:beading/domain/settings/app_info.dart';
import 'package:beading/domain/sharing/biser/biser_file_source.dart';
import 'package:beading/domain/sharing/biser/export_projects.dart';
import 'package:beading/domain/sharing/biser/import_biser.dart';
import 'package:beading/domain/sharing/file_sharer.dart';
import 'package:beading/domain/sharing/text_sharer.dart';
import 'package:beading/domain/sharing/unit_of_work.dart';
import 'package:beading/presentation/sharing/data_transfer_cubit.dart';

import 'fake_book_work.dart';
import 'fake_clock.dart';
import 'fake_grid_pattern.dart';
import 'fake_image_pattern.dart';
import 'fake_project_repository.dart';
import 'fake_work_sessions.dart';

class FakeFileSharer implements FileSharer {
  final List<({Uint8List bytes, String fileName, ShareOrigin? origin})> shared =
      <({Uint8List bytes, String fileName, ShareOrigin? origin})>[];
  Failure? failure;

  @override
  Future<Result<void>> shareFile({required Uint8List bytes, required String fileName, ShareOrigin? origin}) async {
    shared.add((bytes: bytes, fileName: fileName, origin: origin));
    return failure == null ? const Success<void>(null) : Err<void>(failure!);
  }
}

class FakeBiserFilePicker implements BiserFilePicker {
  Result<BiserFile?> next = const Success<BiserFile?>(null);

  @override
  Future<Result<BiserFile?>> pick() async => next;
}

/// Без транзакции: просто выполняет действие.
class PassThroughUnitOfWork implements UnitOfWork {
  @override
  Future<Result<T>> run<T>(Future<Result<T>> Function() action) => action();
}

class _AppInfo implements AppInfoProvider {
  @override
  Future<AppInfo> load() async => const AppInfo(version: '0.1.0', build: '1');
}

/// Кубит обмена файлами на фейках: без базы и платформы.
DataTransferCubit fakeDataTransfer({FileSharer? sharer, BiserFilePicker? picker, FakeProjectRepository? projects}) {
  final FakeProjectRepository repo = projects ?? FakeProjectRepository();
  final FakeGridPatternRepository grids = FakeGridPatternRepository();
  final FakeGridProgressStore progress = FakeGridProgressStore();
  final FakeImagePatternRepository images = FakeImagePatternRepository();
  final FakeBookWorkRepository bookWork = FakeBookWorkRepository();
  final FakeWorkSessionRepository workSessions = FakeWorkSessionRepository();
  final FakeFileStore files = FakeFileStore();
  final Clock clock = FakeClock(DateTime.utc(2026, 11, 10));
  return DataTransferCubit(
    export: ExportProjects(
      projects: repo,
      grids: grids,
      progress: progress,
      images: images,
      bookWork: bookWork,
      workSessions: workSessions,
      files: files,
      codec: const ZipBiserCodec(),
      clock: clock,
      appInfo: _AppInfo(),
    ),
    import: ImportBiser(
      codec: const ZipBiserCodec(),
      projects: repo,
      grids: grids,
      progress: progress,
      images: images,
      bookWork: bookWork,
      workSessions: workSessions,
      files: files,
      ids: FakeIdGenerator(),
      unitOfWork: PassThroughUnitOfWork(),
    ),
    sharer: sharer ?? FakeFileSharer(),
    picker: picker ?? FakeBiserFilePicker(),
  );
}
