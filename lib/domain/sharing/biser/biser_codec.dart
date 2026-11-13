import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:beading/domain/sharing/biser/biser_models.dart';

/// Упаковка [BiserBundle] в байты файла `.biser` и обратно.
abstract interface class BiserCodec {
  Result<Uint8List> encode(BiserBundle bundle);

  /// Повреждённый или неизвестной версии файл — `ValidationFailure` с понятным текстом.
  Result<BiserBundle> decode(Uint8List bytes);
}
