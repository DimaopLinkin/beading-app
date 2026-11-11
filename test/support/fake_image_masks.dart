import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:beading/domain/image_to_grid/image_masks.dart';

/// Фейк `ImageMasks`: отдаёт заданный набор масок или ошибку; помнит, с какими размерами его позвали.
class FakeImageMasks implements ImageMasks {
  FakeImageMasks({this.result, this.failure});

  /// Что вернуть; `null` и нет [failure] — пустой набор нужного размера.
  ImageMaskSet? result;
  Failure? failure;
  Error? throwing;

  /// Если задан, ответ приходит только после его завершения.
  Future<void>? gate;
  final List<({int width, int height})> calls = <({int width, int height})>[];

  @override
  Future<Result<ImageMaskSet>> analyze(Uint8List image, {required int width, required int height}) async {
    calls.add((width: width, height: height));
    if (gate != null) await gate;
    if (throwing != null) throw throwing!;
    if (failure != null) return Err<ImageMaskSet>(failure!);
    return Success<ImageMaskSet>(result ?? ImageMaskSet.empty(width: width, height: height));
  }
}
