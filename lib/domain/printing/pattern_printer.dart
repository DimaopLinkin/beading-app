import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/printing/print_options.dart';

/// Рисует схему вышивки для печати: PDF в масштабе 10 крестиков = 3 см, легенда отдельным листом A4.
abstract interface class PatternPrinter {
  /// PDF схемы [pattern] под заголовком [title]; ошибка рисования приходит как `UnexpectedFailure`.
  Future<Result<Uint8List>> renderPdf({
    required String title,
    required GridPattern pattern,
    PrintOptions options = const PrintOptions(),
  });
}
