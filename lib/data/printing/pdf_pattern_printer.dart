import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/printing/raster_pdf_writer.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/printing/pattern_printer.dart';
import 'package:beading/domain/printing/print_layout.dart';
import 'package:beading/domain/printing/print_options.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_layers_codec.dart';

/// PDF схемы: каждая страница рисуется на холсте, растром 254 dpi, и кладётся в PDF целиком.
///
/// Растр, а не текст PDF: знаки (буквы, фигуры, греческие) рисует системный шрифт, как на экране, и встраивать шрифт
/// не нужно. Клетка 30 пикселей = 3 мм.
class PdfPatternPrinter implements PatternPrinter {
  const PdfPatternPrinter({
    this.pageLabel = _defaultPageLabel,
    this.scaleNote = _defaultScaleNote,
    this.legendTitle = 'легенда',
  });

  /// «Страница 3 из 12, колонки …» — подпись внизу листа.
  final String Function(String title, int page, int pages, PrintTile tile) pageLabel;
  final String scaleNote;
  final String legendTitle;

  static String _defaultPageLabel(String title, int page, int pages, PrintTile tile) =>
      '$title · $page/$pages · ${tile.column + 1}–${tile.columnEnd} × ${tile.row + 1}–${tile.rowEnd}';

  static const String _defaultScaleNote = '10 крестиков = 3 см';

  @override
  Future<Result<Uint8List>> renderPdf({
    required String title,
    required GridPattern pattern,
    PrintOptions options = const PrintOptions(),
  }) async {
    try {
      final PrintLayout layout = PrintLayout(options.paper);
      final StitchLayers? layers = _layers(pattern);
      final List<PrintTile> tiles = layout.tiles(columns: pattern.grid.width, rows: pattern.grid.height);
      if (tiles.isEmpty) return const Err<Uint8List>(ValidationFailure('Пустая схема'));
      final int legendPages = LegendLayout.pageCount(pattern.palette.length);
      final int total = tiles.length + legendPages;
      final List<RasterPage> pages = <RasterPage>[];
      for (int i = 0; i < tiles.length; i++) {
        pages.add(await _renderPage(title, layout, pattern, layers, tiles[i], i + 1, total));
      }
      for (int i = 0; i < legendPages; i++) {
        pages.add(await _renderLegend(title, pattern, options, i, tiles.length + i + 1, total));
      }
      return Success<Uint8List>(const RasterPdfWriter().build(pages));
    } on Object catch (e) {
      return Err<Uint8List>(UnexpectedFailure('Не удалось собрать PDF: $e'));
    }
  }

  static StitchLayers? _layers(GridPattern pattern) {
    final blob = pattern.layers;
    if (blob == null) return null;
    return StitchLayersCodec.fromBlob(blob).valueOrNull;
  }

  Future<RasterPage> _renderPage(
    String title,
    PrintLayout layout,
    GridPattern pattern,
    StitchLayers? layers,
    PrintTile tile,
    int page,
    int pages,
  ) {
    final int width = layout.pageWidthPx;
    final int height = layout.pageHeightPx;
    final double k = layout.pixelsPerMm / 10;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    _drawGrid(canvas, layout, pattern, tile);
    _drawBackstitch(canvas, layout, pattern, layers, tile);
    _drawAxes(canvas, layout, tile);
    _paragraph(
      canvas,
      '${pageLabel(title, page, pages, tile)} · $scaleNote',
      left: layout.marginPx.toDouble(),
      top: height - layout.marginPx - layout.footerPx + 30 * k,
      width: (width - 2 * layout.marginPx).toDouble(),
      size: 28 * k,
      color: const ui.Color(0xFF444444),
    );
    return _raster(recorder, width, height, layout.paper);
  }

  /// Лист легенды A4: номер места на стойке, цвет со знаком, бренд, номер и название нитки.
  Future<RasterPage> _renderLegend(
    String title,
    GridPattern pattern,
    PrintOptions options,
    int index,
    int page,
    int pages,
  ) {
    const int width = LegendLayout.pageWidthPx;
    const int height = LegendLayout.pageHeightPx;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    const double margin = LegendLayout.marginPx + 0.0;
    _paragraph(
      canvas,
      '$title · $legendTitle',
      left: margin,
      top: margin,
      width: width - 2 * margin,
      size: 48,
      color: const ui.Color(0xFF000000),
      weight: ui.FontWeight.w600,
    );
    const double colWidth = (width - 2 * margin - LegendLayout.columnGapPx) / LegendLayout.columnsPerPage;
    const double rowH = LegendLayout.rowPx + 0.0;
    final int total = pattern.palette.length;
    final int first = index * LegendLayout.rowsPerPage;
    for (int n = 0; n < LegendLayout.rowsPerPage && first + n < total; n++) {
      final int column = n ~/ LegendLayout.rowsPerColumn;
      final double x = margin + column * (colWidth + LegendLayout.columnGapPx);
      final double y = margin + LegendLayout.titlePx + (n % LegendLayout.rowsPerColumn) * rowH;
      final PatternColor color = pattern.palette.colors[first + n];
      final ui.Color rgb = _flutterColor(color);
      _paragraph(
        canvas,
        options.slotLabel(first + n, total),
        left: x,
        top: y + 8,
        width: 130,
        size: 34,
        color: const ui.Color(0xFF000000),
        weight: ui.FontWeight.w600,
      );
      final ui.Rect box = ui.Rect.fromLTWH(x + 150, y + 3, rowH - 6, rowH - 6);
      canvas.drawRect(box, ui.Paint()..color = rgb);
      canvas.drawRect(
        box,
        ui.Paint()
          ..color = const ui.Color(0xFF000000)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (color.symbol != null) {
        _paragraph(
          canvas,
          color.symbol!,
          left: box.left,
          top: box.top + 8,
          width: box.width,
          size: 34,
          color: _inkOn(rgb),
          weight: ui.FontWeight.w600,
          center: true,
        );
      }
      final String article = color.components.join(' + ');
      final String label = color.name.isEmpty || color.name == article ? article : '$article  ${color.name}';
      _paragraph(
        canvas,
        label,
        left: x + 150 + rowH + 14,
        top: y + 10,
        width: colWidth - 150 - rowH - 14,
        size: 30,
        color: const ui.Color(0xFF000000),
      );
    }
    _paragraph(
      canvas,
      '$page/$pages',
      left: margin,
      top: height - margin - LegendLayout.footerPx + 30.0,
      width: width - 2 * margin,
      size: 28,
      color: const ui.Color(0xFF444444),
    );
    return _raster(recorder, width, height, LegendLayout.paper);
  }

  Future<RasterPage> _raster(ui.PictureRecorder recorder, int width, int height, PrintPaper paper) async {
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(width, height);
    final ByteData? data = await image.toByteData();
    picture.dispose();
    image.dispose();
    if (data == null) throw StateError('нет пикселей страницы');
    final Uint8List rgba = data.buffer.asUint8List();
    final Uint8List rgb = Uint8List(width * height * 3);
    for (int i = 0, j = 0; i < rgba.length; i += 4, j += 3) {
      rgb[j] = rgba[i];
      rgb[j + 1] = rgba[i + 1];
      rgb[j + 2] = rgba[i + 2];
    }
    return RasterPage(width: width, height: height, rgb: rgb, widthMm: paper.widthMm, heightMm: paper.heightMm);
  }

  static ui.Color _flutterColor(PatternColor c) => ui.Color.fromARGB(255, c.rgb.r, c.rgb.g, c.rgb.b);

  /// Знак на заливке: чёрный или белый по яркости, как на экране.
  static ui.Color _inkOn(ui.Color fill) =>
      fill.computeLuminance() > 0.45 ? const ui.Color(0xFF151316) : const ui.Color(0xFFFFFFFF);

  void _drawGrid(ui.Canvas canvas, PrintLayout layout, GridPattern pattern, PrintTile tile) {
    final int cell = layout.cellPx;
    final Grid grid = pattern.grid;
    final ui.Paint fill = ui.Paint();
    for (int r = 0; r < tile.rows; r++) {
      for (int c = 0; c < tile.columns; c++) {
        final int value = grid.cells[(tile.row + r) * grid.width + tile.column + c];
        final ui.Rect rect = ui.Rect.fromLTWH(
          (layout.gridLeftPx + c * cell).toDouble(),
          (layout.gridTopPx + r * cell).toDouble(),
          cell.toDouble(),
          cell.toDouble(),
        );
        final PatternColor? color = pattern.palette.colorAt(value);
        if (color == null) continue;
        final ui.Color rgb = _flutterColor(color);
        canvas.drawRect(rect, fill..color = rgb);
        final String? symbol = color.symbol;
        if (symbol != null) {
          _paragraph(
            canvas,
            symbol,
            left: rect.left,
            top: rect.top + 2,
            width: cell.toDouble(),
            size: 24 * layout.pixelsPerMm / 10,
            color: _inkOn(rgb),
            weight: ui.FontWeight.w600,
            center: true,
          );
        }
      }
    }
    final double gridW = (tile.columns * cell).toDouble();
    final double gridH = (tile.rows * cell).toDouble();
    final double left = layout.gridLeftPx.toDouble();
    final double top = layout.gridTopPx.toDouble();
    final ui.Paint thin = ui.Paint()
      ..color = const ui.Color(0xFF8A8A8A)
      ..strokeWidth = 1;
    final ui.Paint thick = ui.Paint()
      ..color = const ui.Color(0xFF000000)
      ..strokeWidth = 4;
    for (int c = 0; c <= tile.columns; c++) {
      final double x = left + c * cell;
      canvas.drawLine(ui.Offset(x, top), ui.Offset(x, top + gridH), thin);
    }
    for (int r = 0; r <= tile.rows; r++) {
      final double y = top + r * cell;
      canvas.drawLine(ui.Offset(left, y), ui.Offset(left + gridW, y), thin);
    }
    for (final int abs in PrintLayout.majorLines(tile.column, tile.columnEnd)) {
      final double x = left + (abs - tile.column) * cell;
      canvas.drawLine(ui.Offset(x, top), ui.Offset(x, top + gridH), thick);
    }
    for (final int abs in PrintLayout.majorLines(tile.row, tile.rowEnd)) {
      final double y = top + (abs - tile.row) * cell;
      canvas.drawLine(ui.Offset(left, y), ui.Offset(left + gridW, y), thick);
    }
    canvas.drawRect(
      ui.Rect.fromLTWH(left, top, gridW, gridH),
      ui.Paint()
        ..color = const ui.Color(0xFF000000)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  void _drawBackstitch(
    ui.Canvas canvas,
    PrintLayout layout,
    GridPattern pattern,
    StitchLayers? layers,
    PrintTile tile,
  ) {
    if (layers == null || layers.lines.isEmpty) return;
    final double half = layout.cellPx / 2;
    final double left = layout.gridLeftPx - tile.column * 2 * half;
    final double top = layout.gridTopPx - tile.row * 2 * half;
    canvas.save();
    canvas.clipRect(
      ui.Rect.fromLTWH(
        layout.gridLeftPx.toDouble(),
        layout.gridTopPx.toDouble(),
        (tile.columns * layout.cellPx).toDouble(),
        (tile.rows * layout.cellPx).toDouble(),
      ),
    );
    for (final LineStitch line in layers.lines) {
      final PatternColor? color = pattern.palette.colorAt(line.color);
      if (color == null) continue;
      final ui.Color rgb = _flutterColor(color);
      final ui.Offset a = ui.Offset(left + line.from.x * half, top + line.from.y * half);
      final ui.Offset b = ui.Offset(left + line.to.x * half, top + line.to.y * half);
      // Тёмная подложка, чтобы светлая нитка не терялась на заливке.
      canvas.drawLine(
        a,
        b,
        ui.Paint()
          ..color = _inkOn(rgb) == const ui.Color(0xFFFFFFFF) ? const ui.Color(0xFFFFFFFF) : const ui.Color(0xFF000000)
          ..strokeWidth = 9
          ..strokeCap = ui.StrokeCap.round,
      );
      canvas.drawLine(
        a,
        b,
        ui.Paint()
          ..color = rgb
          ..strokeWidth = 5
          ..strokeCap = ui.StrokeCap.round,
      );
    }
    canvas.restore();
  }

  void _drawAxes(ui.Canvas canvas, PrintLayout layout, PrintTile tile) {
    final int cell = layout.cellPx;
    final double left = layout.gridLeftPx.toDouble();
    final double top = layout.gridTopPx.toDouble();
    final double gridW = (tile.columns * cell).toDouble();
    final double gridH = (tile.rows * cell).toDouble();
    const ui.Color ink = ui.Color(0xFF000000);
    for (final int abs in PrintLayout.majorLines(tile.column, tile.columnEnd)) {
      final double x = left + (abs - tile.column) * cell;
      for (final double y in <double>[top - layout.axisPx + 12, top + gridH + 8]) {
        _paragraph(
          canvas,
          '$abs',
          left: x - 60,
          top: y,
          width: 120,
          size: 32 * layout.pixelsPerMm / 10,
          color: ink,
          center: true,
        );
      }
    }
    for (final int abs in PrintLayout.majorLines(tile.row, tile.rowEnd)) {
      final double y = top + (abs - tile.row) * cell - 20;
      _paragraph(
        canvas,
        '$abs',
        left: left - layout.axisPx - 10,
        top: y,
        width: 80,
        size: 32 * layout.pixelsPerMm / 10,
        color: ink,
        center: true,
      );
      _paragraph(
        canvas,
        '$abs',
        left: left + gridW + 6,
        top: y,
        width: 80,
        size: 32 * layout.pixelsPerMm / 10,
        color: ink,
        center: true,
      );
    }
  }

  void _paragraph(
    ui.Canvas canvas,
    String text, {
    required double left,
    required double top,
    required double width,
    required double size,
    required ui.Color color,
    ui.FontWeight weight = ui.FontWeight.w400,
    bool center = false,
    int maxLines = 1,
  }) {
    final ui.ParagraphBuilder builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: center ? ui.TextAlign.center : ui.TextAlign.left,
              maxLines: maxLines,
              ellipsis: '…',
              fontSize: size,
              fontWeight: weight,
            ),
          )
          ..pushStyle(ui.TextStyle(color: color, fontSize: size, fontWeight: weight))
          ..addText(text);
    final ui.Paragraph paragraph = builder.build()..layout(ui.ParagraphConstraints(width: width));
    canvas.drawParagraph(paragraph, ui.Offset(left, top));
    paragraph.dispose();
  }
}
