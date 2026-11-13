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
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_layers_codec.dart';

/// PDF схемы: каждая страница рисуется на холсте, растром 254 dpi, и кладётся в PDF целиком.
///
/// Растр, а не текст PDF: знаки (буквы, фигуры, греческие) рисует системный шрифт, как на экране, и встраивать шрифт
/// не нужно. Клетка 30 пикселей = 3 мм.
class PdfPatternPrinter implements PatternPrinter {
  const PdfPatternPrinter({this.pageLabel = _defaultPageLabel, this.scaleNote = _defaultScaleNote});

  /// «Страница 3 из 12, колонки …» — подпись внизу листа.
  final String Function(String title, int page, int pages, PrintTile tile) pageLabel;
  final String scaleNote;

  static String _defaultPageLabel(String title, int page, int pages, PrintTile tile) =>
      '$title · $page/$pages · ${tile.column + 1}–${tile.columnEnd} × ${tile.row + 1}–${tile.rowEnd}';

  static const String _defaultScaleNote = '10 крестиков = 3 см';

  @override
  Future<Result<Uint8List>> renderPdf({required String title, required GridPattern pattern}) async {
    try {
      final StitchLayers? layers = _layers(pattern);
      final List<PrintTile> tiles = PrintLayout.tiles(columns: pattern.grid.width, rows: pattern.grid.height);
      if (tiles.isEmpty) return const Err<Uint8List>(ValidationFailure('Пустая схема'));
      final List<RasterPage> pages = <RasterPage>[];
      for (int i = 0; i < tiles.length; i++) {
        pages.add(await _renderPage(title, pattern, layers, tiles[i], i + 1, tiles.length));
      }
      return Success<Uint8List>(
        const RasterPdfWriter(
          pageWidthMm: PrintLayout.pageWidthMm,
          pageHeightMm: PrintLayout.pageHeightMm,
        ).build(pages),
      );
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
    GridPattern pattern,
    StitchLayers? layers,
    PrintTile tile,
    int page,
    int pages,
  ) async {
    const int width = PrintLayout.pageWidthPx;
    const int height = PrintLayout.pageHeightPx;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    _drawGrid(canvas, pattern, tile);
    _drawBackstitch(canvas, pattern, layers, tile);
    _drawAxes(canvas, tile);
    _drawLegend(canvas, pattern, tile);
    _paragraph(
      canvas,
      '${pageLabel(title, page, pages, tile)} · $scaleNote',
      left: PrintLayout.marginPx.toDouble(),
      top: (height - PrintLayout.marginPx - PrintLayout.footerPx + 30).toDouble(),
      width: (width - 2 * PrintLayout.marginPx).toDouble(),
      size: 28,
      color: const ui.Color(0xFF444444),
    );
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
    return RasterPage(width: width, height: height, rgb: rgb);
  }

  static ui.Color _flutterColor(PatternColor c) => ui.Color.fromARGB(255, c.rgb.r, c.rgb.g, c.rgb.b);

  /// Знак на заливке: чёрный или белый по яркости, как на экране.
  static ui.Color _inkOn(ui.Color fill) =>
      fill.computeLuminance() > 0.45 ? const ui.Color(0xFF151316) : const ui.Color(0xFFFFFFFF);

  void _drawGrid(ui.Canvas canvas, GridPattern pattern, PrintTile tile) {
    const int cell = PrintLayout.cellPx;
    final Grid grid = pattern.grid;
    final ui.Paint fill = ui.Paint();
    for (int r = 0; r < tile.rows; r++) {
      for (int c = 0; c < tile.columns; c++) {
        final int value = grid.cells[(tile.row + r) * grid.width + tile.column + c];
        final ui.Rect rect = ui.Rect.fromLTWH(
          (PrintLayout.gridLeftPx + c * cell).toDouble(),
          (PrintLayout.gridTopPx + r * cell).toDouble(),
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
            size: 24,
            color: _inkOn(rgb),
            weight: ui.FontWeight.w600,
            center: true,
          );
        }
      }
    }
    final double gridW = (tile.columns * cell).toDouble();
    final double gridH = (tile.rows * cell).toDouble();
    final double left = PrintLayout.gridLeftPx.toDouble();
    final double top = PrintLayout.gridTopPx.toDouble();
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

  void _drawBackstitch(ui.Canvas canvas, GridPattern pattern, StitchLayers? layers, PrintTile tile) {
    if (layers == null || layers.lines.isEmpty) return;
    const double half = PrintLayout.cellPx / 2;
    final double left = PrintLayout.gridLeftPx - tile.column * 2 * half;
    final double top = PrintLayout.gridTopPx - tile.row * 2 * half;
    canvas.save();
    canvas.clipRect(
      ui.Rect.fromLTWH(
        PrintLayout.gridLeftPx.toDouble(),
        PrintLayout.gridTopPx.toDouble(),
        (tile.columns * PrintLayout.cellPx).toDouble(),
        (tile.rows * PrintLayout.cellPx).toDouble(),
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

  void _drawAxes(ui.Canvas canvas, PrintTile tile) {
    const int cell = PrintLayout.cellPx;
    final double left = PrintLayout.gridLeftPx.toDouble();
    final double top = PrintLayout.gridTopPx.toDouble();
    final double gridW = (tile.columns * cell).toDouble();
    final double gridH = (tile.rows * cell).toDouble();
    const ui.Color ink = ui.Color(0xFF000000);
    for (final int abs in PrintLayout.majorLines(tile.column, tile.columnEnd)) {
      final double x = left + (abs - tile.column) * cell;
      for (final double y in <double>[top - PrintLayout.axisPx + 12, top + gridH + 8]) {
        _paragraph(canvas, '$abs', left: x - 60, top: y, width: 120, size: 32, color: ink, center: true);
      }
    }
    for (final int abs in PrintLayout.majorLines(tile.row, tile.rowEnd)) {
      final double y = top + (abs - tile.row) * cell - 20;
      _paragraph(
        canvas,
        '$abs',
        left: left - PrintLayout.axisPx - 10,
        top: y,
        width: 80,
        size: 32,
        color: ink,
        center: true,
      );
      _paragraph(canvas, '$abs', left: left + gridW + 6, top: y, width: 80, size: 32, color: ink, center: true);
    }
  }

  void _drawLegend(ui.Canvas canvas, GridPattern pattern, PrintTile tile) {
    final Grid grid = pattern.grid;
    final Map<int, int> counts = <int, int>{};
    for (int r = 0; r < tile.rows; r++) {
      for (int c = 0; c < tile.columns; c++) {
        final int value = grid.cells[(tile.row + r) * grid.width + tile.column + c];
        if (value != 0) counts.update(value, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final List<int> used = counts.keys.toList()..sort();
    if (used.isEmpty) return;
    const double left = PrintLayout.legendLeftPx + 0;
    const double top = PrintLayout.gridTopPx + 0;
    const double available = PrintLayout.pageHeightPx - PrintLayout.marginPx - PrintLayout.footerPx - top;
    final double rowH = (available / used.length).clamp(30, 52).toDouble();
    final int capacity = (available / rowH).floor();
    final double swatch = rowH - 6;
    for (int i = 0; i < used.length && i < capacity; i++) {
      final PatternColor? color = pattern.palette.colorAt(used[i]);
      if (color == null) continue;
      final double y = top + i * rowH;
      final ui.Color rgb = _flutterColor(color);
      final ui.Rect box = ui.Rect.fromLTWH(left, y + 3, swatch, swatch);
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
          top: box.top + (swatch - rowH * 0.55) / 2 - 2,
          width: swatch,
          size: rowH * 0.55,
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
        left: left + swatch + 14,
        top: y + (rowH - rowH * 0.5) / 2 - 3,
        width: PrintLayout.legendWidthPx - swatch - 14,
        size: rowH * 0.5,
        color: const ui.Color(0xFF000000),
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
