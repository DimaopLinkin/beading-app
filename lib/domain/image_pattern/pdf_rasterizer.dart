import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/image_processor.dart';

/// Растеризует страницы PDF в PNG.
abstract interface class PdfRasterizer {
  Future<Result<int>> pageCount(Uint8List pdf);

  /// Страницы с номерами [pageIndexes] (с нуля) в том же порядке. [scale] — во сколько раз крупнее размера страницы в пунктах.
  Future<Result<List<ProcessedImage>>> render(Uint8List pdf, List<int> pageIndexes, {double scale = 2});
}
