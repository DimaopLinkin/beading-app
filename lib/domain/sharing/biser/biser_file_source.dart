import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:equatable/equatable.dart';

/// Прочитанный файл `.biser`.
final class BiserFile extends Equatable {
  const BiserFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  @override
  List<Object?> get props => <Object?>[name, bytes];
}

/// Выбор файла `.biser` в «Файлах».
abstract interface class BiserFilePicker {
  /// `Success(null)` — выбор отменили.
  Future<Result<BiserFile?>> pick();
}

/// Файлы `.biser`, которые система открыла в приложении (AirDrop, «Файлы», двойной щелчок в Finder).
abstract interface class IncomingBiserFiles {
  /// Каждый открытый файл, в том числе тот, которым приложение было запущено.
  Stream<Result<BiserFile>> get files;
}
