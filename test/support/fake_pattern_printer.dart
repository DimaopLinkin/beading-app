import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/printing/pattern_printer.dart';
import 'package:beading/domain/printing/print_options.dart';

/// Запоминает вызовы; [failure] — следующая сборка вернёт ошибку.
class FakePatternPrinter implements PatternPrinter {
  final List<({String title, GridPattern pattern, PrintOptions options})> calls =
      <({String title, GridPattern pattern, PrintOptions options})>[];
  Failure? failure;

  @override
  Future<Result<Uint8List>> renderPdf({
    required String title,
    required GridPattern pattern,
    PrintOptions options = const PrintOptions(),
  }) async {
    calls.add((title: title, pattern: pattern, options: options));
    return failure == null ? Success<Uint8List>(Uint8List.fromList(<int>[37, 80, 68, 70])) : Err<Uint8List>(failure!);
  }
}
