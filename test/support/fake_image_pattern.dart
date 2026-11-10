import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';
import 'package:beading/domain/image_pattern/image_pattern_repository.dart';
import 'package:beading/domain/image_pattern/image_processor.dart';
import 'package:beading/domain/image_pattern/pdf_rasterizer.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';

/// Файловая система в памяти. [failWritesAfter] — сколько записей пройдёт до сбоя.
class FakeFileStore implements FileStore {
  final Map<String, Uint8List> files = <String, Uint8List>{};
  int? failWritesAfter;
  bool failCopy = false;
  int _writes = 0;

  @override
  Future<Result<void>> write(String relativePath, Uint8List bytes) async {
    if (failWritesAfter != null && _writes >= failWritesAfter!) {
      return const Err<void>(StorageFailure('диск полон'));
    }
    _writes++;
    files[relativePath] = bytes;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> copy({required String from, required String to}) async {
    final Uint8List? bytes = files[from];
    if (failCopy || bytes == null) {
      return const Err<void>(StorageFailure('не скопировать'));
    }
    files[to] = Uint8List.fromList(bytes);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> delete(String relativePath) async {
    files.remove(relativePath);
    return const Success<void>(null);
  }
}

/// «Обработка» без картинок: PNG — это исходные байты, размер задаётся тестом.
class FakeImageProcessor implements ImageProcessor {
  final List<({int quarterTurns, CropRect crop})> calls = <({int quarterTurns, CropRect crop})>[];
  Failure? failure;

  @override
  Future<Result<ProcessedImage>> process(
    Uint8List bytes, {
    int quarterTurns = 0,
    CropRect crop = CropRect.full,
  }) async {
    calls.add((quarterTurns: quarterTurns, crop: crop));
    if (failure != null) {
      return Err<ProcessedImage>(failure!);
    }
    return Success<ProcessedImage>(ProcessedImage(png: bytes, width: 100, height: 200));
  }
}

class FakeImagePatternRepository implements ImagePatternRepository {
  final Map<String, ImagePattern> byProject = <String, ImagePattern>{};
  Failure? failNextSave;

  @override
  Future<Result<ImagePattern>> getByProject(String projectId) async {
    final ImagePattern? pattern = byProject[projectId];
    return pattern == null
        ? Err<ImagePattern>(NotFoundFailure('нет схемы $projectId'))
        : Success<ImagePattern>(pattern);
  }

  @override
  Future<Result<void>> save(ImagePattern pattern) async {
    if (failNextSave != null) {
      final Failure f = failNextSave!;
      failNextSave = null;
      return Err<void>(f);
    }
    byProject[pattern.projectId] = pattern;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> deleteByProject(String projectId) async {
    byProject.remove(projectId);
    return const Success<void>(null);
  }
}

class FakeBookImageSource implements BookImageSource {
  Result<List<PickedBookFile>> next = const Success<List<PickedBookFile>>(<PickedBookFile>[]);
  final List<String> calls = <String>[];

  @override
  Future<Result<List<PickedBookFile>>> takePhoto() async {
    calls.add('camera');
    return next;
  }

  @override
  Future<Result<List<PickedBookFile>>> pickPhotos() async {
    calls.add('photos');
    return next;
  }

  @override
  Future<Result<List<PickedBookFile>>> pickFiles() async {
    calls.add('files');
    return next;
  }
}

class FakePdfRasterizer implements PdfRasterizer {
  int pages = 3;
  Failure? failure;
  final List<List<int>> rendered = <List<int>>[];

  @override
  Future<Result<int>> pageCount(Uint8List pdf) async => failure != null ? Err<int>(failure!) : Success<int>(pages);

  @override
  Future<Result<List<ProcessedImage>>> render(Uint8List pdf, List<int> pageIndexes, {double scale = 2}) async {
    if (failure != null) {
      return Err<List<ProcessedImage>>(failure!);
    }
    rendered.add(pageIndexes);
    return Success<List<ProcessedImage>>(<ProcessedImage>[
      for (final int i in pageIndexes) ProcessedImage(png: Uint8List.fromList(<int>[i]), width: 10, height: 10),
    ]);
  }
}
