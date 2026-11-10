import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Источники страниц на плагинах: камера и Фото — `image_picker`, Файлы — `file_picker`.
class PickerBookImageSource implements BookImageSource {
  PickerBookImageSource({ImagePicker? imagePicker}) : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<Result<List<PickedBookFile>>> takePhoto() => _guard(() async {
    final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera);
    return photo == null ? const <PickedBookFile>[] : <PickedBookFile>[await _read(photo.name, photo.readAsBytes)];
  });

  @override
  Future<Result<List<PickedBookFile>>> pickPhotos() => _guard(() async {
    final List<XFile> photos = await _imagePicker.pickMultiImage();
    return <PickedBookFile>[for (final XFile photo in photos) await _read(photo.name, photo.readAsBytes)];
  });

  @override
  Future<Result<List<PickedBookFile>>> pickFiles() => _guard(() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf', 'jpg', 'jpeg', 'png', 'heic', 'heif', 'webp'],
    );
    return <PickedBookFile>[for (final PlatformFile file in files) await _read(file.name, file.readAsBytes)];
  });

  Future<PickedBookFile> _read(String name, Future<Uint8List> Function() bytes) async =>
      PickedBookFile(name: name, bytes: await bytes());

  Future<Result<List<PickedBookFile>>> _guard(Future<List<PickedBookFile>> Function() action) async {
    try {
      return Success<List<PickedBookFile>>(await action());
    } on PlatformException catch (error) {
      // Чаще всего — отказ в доступе к камере или Фото.
      return Err<List<PickedBookFile>>(StorageFailure('${error.code}: ${error.message}'));
    }
  }
}
