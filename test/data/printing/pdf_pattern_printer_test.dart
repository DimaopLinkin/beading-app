import 'dart:convert';
import 'dart:typed_data';

import 'package:beading/data/printing/pdf_pattern_printer.dart';
import 'package:beading/data/printing/raster_pdf_writer.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

int _count(Uint8List bytes, String needle) => RegExp(needle).allMatches(latin1.decode(bytes)).length;

void main() {
  test('RasterPdfWriter: заголовок, число страниц и конец файла', () {
    final Uint8List pdf = const RasterPdfWriter(pageWidthMm: 210, pageHeightMm: 297).build(<RasterPage>[
      RasterPage(width: 2, height: 2, rgb: Uint8List(12)),
      RasterPage(width: 2, height: 2, rgb: Uint8List(12)),
    ]);
    final String text = latin1.decode(pdf);
    expect(text, startsWith('%PDF-1.4'));
    expect(text, contains('/Count 2'));
    expect(_count(pdf, '/Type /Page '), 2);
    expect(text.trimRight(), endsWith('%%EOF'));
  });

  testWidgets('PdfPatternPrinter: схема 95×100 — шесть страниц', (tester) async {
    final GridPattern pattern = GridPattern(
      id: 'p',
      projectId: 'proj',
      geometry: const GridGeometry.rectangular(),
      metrics: Fabric.standard,
      grid: Grid.fromCells(width: 95, height: 100, cells: List<int>.generate(9500, (i) => i % 3)),
      palette: PaletteSnapshot(<PatternColor>[
        PatternColor(
          rgb: const Rgb(200, 10, 10),
          name: 'Красный',
          components: const <CatalogRef>[CatalogRef(brand: 'Гамма', code: '3071')],
          symbol: 'A',
        ),
        PatternColor(
          rgb: const Rgb(10, 10, 10),
          name: 'Чёрный',
          components: const <CatalogRef>[CatalogRef(brand: 'Гамма', code: '3095')],
          symbol: 'B',
        ),
      ]),
    );
    final result = await tester.runAsync(() => const PdfPatternPrinter().renderPdf(title: 'Тест', pattern: pattern));
    expect(result!.isSuccess, isTrue, reason: '${result.failureOrNull}');
    final Uint8List pdf = result.valueOrNull!;
    expect(latin1.decode(pdf), startsWith('%PDF-1.4'));
    expect(_count(pdf, '/Type /Page '), 6);
  });
}
