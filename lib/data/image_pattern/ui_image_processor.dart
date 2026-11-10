import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_pattern/image_processor.dart';

/// Обработка картинок средствами движка Flutter: JPEG, PNG, WebP и всё, что умеет система
/// (на iOS и macOS — в том числе HEIC). Результат всегда PNG.
class UiImageProcessor implements ImageProcessor {
  const UiImageProcessor({this.maxSide = 4096});

  /// Длинная сторона результата не больше этого числа пикселей (фото с камеры бывают огромными).
  final int maxSide;

  @override
  Future<Result<ProcessedImage>> process(
    Uint8List bytes, {
    int quarterTurns = 0,
    CropRect crop = CropRect.full,
  }) async {
    ui.Image? source;
    ui.Image? output;
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      try {
        source = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      final int turns = quarterTurns % 4;
      final bool swap = turns.isOdd;
      final int rotatedWidth = swap ? source.height : source.width;
      final int rotatedHeight = swap ? source.width : source.height;

      final double cropLeft = (crop.left * rotatedWidth).roundToDouble();
      final double cropTop = (crop.top * rotatedHeight).roundToDouble();
      final int cropWidth = math.max(1, (crop.width * rotatedWidth).round());
      final int cropHeight = math.max(1, (crop.height * rotatedHeight).round());
      final double scale = math.min(1, maxSide / math.max(cropWidth, cropHeight));
      final int width = math.max(1, (cropWidth * scale).round());
      final int height = math.max(1, (cropHeight * scale).round());

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
        ..scale(width / cropWidth, height / cropHeight)
        ..translate(-cropLeft, -cropTop)
        // Поворот вокруг начала координат уводит картинку в минус; сдвиг возвращает её в поле.
        ..translate(
          turns == 1 || turns == 2 ? rotatedWidth.toDouble() : 0,
          turns == 2 || turns == 3 ? rotatedHeight.toDouble() : 0,
        )
        ..rotate(turns * math.pi / 2)
        ..drawImage(
          source,
          ui.Offset.zero,
          ui.Paint()..filterQuality = scale < 1 ? ui.FilterQuality.high : ui.FilterQuality.none,
        );
      final ui.Picture picture = recorder.endRecording();
      output = await picture.toImage(width, height);
      picture.dispose();

      final ByteData? png = await output.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        return const Err<ProcessedImage>(UnexpectedFailure('Не удалось закодировать PNG'));
      }
      return Success<ProcessedImage>(
        ProcessedImage(png: png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes), width: width, height: height),
      );
    } on Exception catch (error) {
      return Err<ProcessedImage>(ValidationFailure('Не удалось прочитать картинку: $error'));
    } finally {
      source?.dispose();
      output?.dispose();
    }
  }
}
