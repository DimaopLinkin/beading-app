import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_to_grid/image_decoder.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';

/// Декодирует картинку движком Flutter (JPEG, PNG, WebP, на iOS и macOS — и HEIC) и сразу уменьшает до [maxSide].
class UiImageDecoder implements ImageDecoder {
  const UiImageDecoder();

  @override
  Future<Result<SourceImage>> decode(Uint8List bytes, {int maxSide = 1024}) async {
    ui.Image? image;
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      ui.Image scaled = image;
      final double scale = math.min(1, maxSide / math.max(image.width, image.height));
      if (scale < 1) {
        final int width = math.max(1, (image.width * scale).round());
        final int height = math.max(1, (image.height * scale).round());
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        ui.Canvas(recorder)
          ..scale(width / image.width, height / image.height)
          ..drawImage(image, ui.Offset.zero, ui.Paint()..filterQuality = ui.FilterQuality.high);
        final ui.Picture picture = recorder.endRecording();
        scaled = await picture.toImage(width, height);
        picture.dispose();
      }
      final ByteData? raw = await scaled.toByteData();
      if (raw == null) {
        return const Err<SourceImage>(UnexpectedFailure('Не удалось получить пиксели'));
      }
      final SourceImage result = SourceImage(
        width: scaled.width,
        height: scaled.height,
        rgba: raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes),
      );
      if (!identical(scaled, image)) {
        scaled.dispose();
      }
      return Success<SourceImage>(result);
    } on Exception catch (error) {
      return Err<SourceImage>(ValidationFailure('Не удалось прочитать картинку: $error'));
    } finally {
      image?.dispose();
    }
  }
}
