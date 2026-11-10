import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/image_processor.dart';
import 'package:beading/domain/image_pattern/pdf_rasterizer.dart';
import 'package:pdfrx/pdfrx.dart';

/// Растеризация PDF через pdfium (пакет `pdfrx`).
class PdfrxPdfRasterizer implements PdfRasterizer {
  /// [initialize] готовит pdfium к работе; в приложении это `pdfrxFlutterInitialize`, в тестах подменяется.
  PdfrxPdfRasterizer({Future<void> Function()? initialize}) : _initialize = initialize ?? _defaultInitialize;

  final Future<void> Function() _initialize;
  Future<void>? _ready;

  static Future<void> _defaultInitialize() => pdfrxFlutterInitialize();

  @override
  Future<Result<int>> pageCount(Uint8List pdf) =>
      _withDocument(pdf, (document) => Future<int>.value(document.pages.length));

  @override
  Future<Result<List<ProcessedImage>>> render(Uint8List pdf, List<int> pageIndexes, {double scale = 2}) =>
      _withDocument(pdf, (document) async {
        final List<ProcessedImage> result = <ProcessedImage>[];
        for (final int index in pageIndexes) {
          if (index < 0 || index >= document.pages.length) {
            throw RangeError.range(index, 0, document.pages.length - 1, 'pageIndex');
          }
          final PdfPage page = document.pages[index];
          final PdfImage? image = await page.render(
            fullWidth: page.width * scale,
            fullHeight: page.height * scale,
            backgroundColor: 0xFFFFFFFF,
          );
          if (image == null) {
            throw StateError('Страница ${index + 1} не отрисовалась');
          }
          try {
            result.add(await _toPng(image));
          } finally {
            image.dispose();
          }
        }
        return result;
      });

  Future<Result<T>> _withDocument<T>(Uint8List pdf, Future<T> Function(PdfDocument document) action) async {
    PdfDocument? document;
    try {
      await (_ready ??= _initialize());
      document = await PdfDocument.openData(pdf);
      return Success<T>(await action(document));
    } on RangeError catch (error) {
      return Err<T>(ValidationFailure('${error.message}'));
    } on Exception catch (error) {
      return Err<T>(ValidationFailure('Не удалось открыть PDF: $error'));
    } on StateError catch (error) {
      return Err<T>(UnexpectedFailure(error.message));
    } finally {
      await document?.dispose();
    }
  }

  Future<ProcessedImage> _toPng(PdfImage image) async {
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(image.pixels);
    final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: image.width,
      height: image.height,
      pixelFormat: ui.PixelFormat.bgra8888,
    );
    final ui.Codec codec = await descriptor.instantiateCodec();
    final ui.Image decoded = (await codec.getNextFrame()).image;
    try {
      final ByteData? png = await decoded.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw StateError('Не удалось закодировать PNG');
      }
      return ProcessedImage(
        png: png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        width: image.width,
        height: image.height,
      );
    } finally {
      decoded.dispose();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
    }
  }
}
