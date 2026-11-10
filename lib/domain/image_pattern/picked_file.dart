import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:equatable/equatable.dart';

/// Файл, выбранный пользователем: фото со снимка, из Фото или из Файлов.
class PickedFile extends Equatable {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  /// PDF узнаём по сигнатуре `%PDF`, а не по имени: из «Фото» и «Файлов» имя бывает любым.
  bool get isPdf =>
      bytes.length >= 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46;

  @override
  List<Object?> get props => <Object?>[name, bytes];
}

/// Откуда берём страницы схемы. Пустой список — пользователь закрыл выбор.
abstract interface class BookImageSource {
  Future<Result<List<PickedFile>>> takePhoto();

  Future<Result<List<PickedFile>>> pickPhotos();

  Future<Result<List<PickedFile>>> pickFiles();
}
