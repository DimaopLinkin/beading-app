import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/printing/pattern_printer.dart';

/// Запоминает вызовы; [failure] — следующая сборка вернёт ошибку.
class FakePatternPrinter implements PatternPrinter {
  final List<({String title, GridPattern pattern})> calls = <({String title, GridPattern pattern})>[];
  Failure? failure;

  @override
  Future<Result<Uint8List>> renderPdf({required String title, required GridPattern pattern}) async {
    calls.add((title: title, pattern: pattern));
    return failure == null ? Success<Uint8List>(Uint8List.fromList(<int>[37, 80, 68, 70])) : Err<Uint8List>(failure!);
  }
}
