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
import 'package:beading/domain/printing/print_layout.dart';
import 'package:beading/domain/printing/print_options.dart';
import 'package:flutter_test/flutter_test.dart';

int _count(Uint8List bytes, String needle) => RegExp(needle).allMatches(latin1.decode(bytes)).length;

void main() {
  test('RasterPdfWriter: заголовок, число страниц и конец файла', () {
    final Uint8List pdf = const RasterPdfWriter().build(<RasterPage>[
      RasterPage(width: 2, height: 2, rgb: Uint8List(12), widthMm: 210, heightMm: 297),
      RasterPage(width: 2, height: 2, rgb: Uint8List(12), widthMm: 420, heightMm: 594),
    ]);
    final String text = latin1.decode(pdf);
    expect(text, startsWith('%PDF-1.4'));
    expect(text, contains('/Count 2'));
    expect(_count(pdf, '/Type /Page '), 2);
    expect(text, contains('/MediaBox [0 0 1190.55 1683.78]'), reason: 'A2');
    expect(text.trimRight(), endsWith('%%EOF'));
  });

  GridPattern pattern(int columns, int rows) => GridPattern(
    id: 'p',
    projectId: 'proj',
    geometry: const GridGeometry.rectangular(),
    metrics: Fabric.standard,
    grid: Grid.fromCells(width: columns, height: rows, cells: List<int>.generate(columns * rows, (i) => i % 3)),
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

  for (final PrintPaper paper in PrintPaper.values) {
    testWidgets('PdfPatternPrinter ${paper.name}: листы схемы плюс лист легенды, число страниц как в расчёте', (
      tester,
    ) async {
      final GridPattern p = pattern(130, 100);
      final PrintOptions options = PrintOptions(paper: paper);
      final int expected = PrintLayout(paper).pageCount(columns: 130, rows: 100, colors: p.palette.length);
      final result = await tester.runAsync(
        () => const PdfPatternPrinter().renderPdf(title: 'Тест', pattern: p, options: options),
      );
      expect(result!.isSuccess, isTrue, reason: '${result.failureOrNull}');
      final Uint8List pdf = result.valueOrNull!;
      expect(latin1.decode(pdf), startsWith('%PDF-1.4'));
      expect(_count(pdf, '/Type /Page '), expected);
      // Последний лист — легенда A4.
      expect(latin1.decode(pdf), contains('/MediaBox [0 0 595.28 841.89]'));
    });
  }
}
