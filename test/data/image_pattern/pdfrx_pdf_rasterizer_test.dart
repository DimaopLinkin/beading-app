import 'dart:io';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/image_pattern/pdfrx_pdf_rasterizer.dart';
import 'package:beading/domain/image_pattern/image_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../support/test_images.dart';

/// Библиотеку pdfium скачивает хук сборки пакета `pdfium_dart` при первом `flutter test`.
String? _findPdfium() {
  final Directory build = Directory('.dart_tool/hooks_runner/shared/pdfium_dart/build');
  if (!build.existsSync()) {
    return null;
  }
  final String suffix = Platform.isMacOS ? 'libpdfium.dylib' : 'libpdfium.so';
  for (final FileSystemEntity entity in build.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith(suffix)) {
      return entity.absolute.path;
    }
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final String? pdfium = _findPdfium();
  final Uint8List fixture = File('test/fixtures/book_3_pages.pdf').readAsBytesSync();
  late PdfrxPdfRasterizer rasterizer;

  setUp(() {
    rasterizer = PdfrxPdfRasterizer(
      initialize: () async {
        Pdfrx.pdfiumModulePath = pdfium;
      },
    );
  });

  // В фикстуре 3 страницы: 200×100, 200×100 и 100×200 пунктов; в каждой красный прямоугольник в левом нижнем углу.
  final Object? skip = pdfium == null ? 'pdfium не найден: сначала нужен `flutter pub get` и сборка хуков' : false;

  test('считает страницы', () async {
    expect((await rasterizer.pageCount(fixture)).valueOrNull, 3);
  }, skip: skip);

  test('рисует выбранные страницы в 2× и в заданном порядке', () async {
    final Result<List<ProcessedImage>> result = await rasterizer.render(fixture, <int>[2, 0]);

    final List<ProcessedImage> pages = result.valueOrNull!;
    expect(pages.map((p) => (p.width, p.height)), <(int, int)>[(200, 400), (400, 200)]);
    final decoded = await decodePng(pages[1].png);
    expect((decoded.width, decoded.height), (400, 200));
    // Фон белый, а красный прямоугольник нарисован: страница не пустая.
    expect(decoded.pixels.first, 0xFFFFFFFF);
    expect(decoded.pixels, contains(0xFFFF0000));
  }, skip: skip);

  test('масштаб меняет размер результата', () async {
    final List<ProcessedImage> pages = (await rasterizer.render(fixture, <int>[0], scale: 1)).valueOrNull!;

    expect((pages.single.width, pages.single.height), (200, 100));
  }, skip: skip);

  test('номер страницы вне документа — ValidationFailure', () async {
    expect((await rasterizer.render(fixture, <int>[3])).failureOrNull, isA<ValidationFailure>());
    expect((await rasterizer.render(fixture, <int>[-1])).failureOrNull, isA<ValidationFailure>());
  }, skip: skip);

  test('не PDF — Failure', () async {
    expect((await rasterizer.pageCount(Uint8List.fromList(<int>[1, 2, 3]))).failureOrNull, isA<Failure>());
  }, skip: skip);
}
