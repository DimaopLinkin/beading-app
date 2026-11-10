import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/sharing/biser/biser_file_source.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

/// Выбор `.biser` в «Файлах» через `file_picker`. Любой тип файла: проверка — при разборе.
class FilePickerBiserPicker implements BiserFilePicker {
  const FilePickerBiserPicker();

  @override
  Future<Result<BiserFile?>> pick() async {
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles();
      if (files.isEmpty) {
        return const Success<BiserFile?>(null);
      }
      final PlatformFile file = files.first;
      return Success<BiserFile?>(BiserFile(name: file.name, bytes: await file.readAsBytes()));
    } on PlatformException catch (error) {
      return Err<BiserFile?>(StorageFailure('${error.code}: ${error.message}'));
    }
  }
}
