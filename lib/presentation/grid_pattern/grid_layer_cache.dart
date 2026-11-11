import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/cell_range.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/presentation/grid_pattern/bead_finish.dart';
import 'package:beading/presentation/grid_pattern/grid_colors.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/grid_pattern/realistic_cells.dart';
import 'package:flutter/painting.dart';

/// Цвета слоя ячеек, уже приведённые к яркости темы. Часть ключа кеша: сменилась тема — слой строится заново.
final class GridPaintStyle {
  const GridPaintStyle({
    required this.line,
    required this.boldLine,
    required this.emptyCell,
    required this.unknown,
    this.realistic = const RealisticColors(surface: Color(0xFFE6E1D8), thread: Color(0xFF9A948A)),
  });

  final Color line;
  final Color boldLine;
  final Color emptyCell;
  final Color unknown;

  /// Подложка и нить вида «как будет выглядеть».
  final RealisticColors realistic;

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, поля final
  bool operator ==(Object other) =>
      other is GridPaintStyle &&
      other.line == line &&
      other.boldLine == boldLine &&
      other.emptyCell == emptyCell &&
      other.unknown == unknown &&
      other.realistic == realistic;

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, см. выше
  int get hashCode => Object.hash(line, boldLine, emptyCell, unknown, realistic);
}

/// Кеш слоя ячеек: `Picture` на блок [blockSize]×[blockSize] ячеек, строится лениво и только для видимых блоков.
///
/// Пока схема, палитра, раскладка и настройки слоя не менялись, повторная отрисовка берёт готовые `Picture` и ничего
/// не перестраивает ([buildCount] не растёт). Подсветка рядов в кеш не входит: она рисуется поверх.
final class GridLayerCache {
  /// Сторона блока, ячеек.
  static const int blockSize = 32;

  final Map<int, Picture> _blocks = <int, Picture>{};
  final Map<(String, bool), TextPainter> _symbols = <(String, bool), TextPainter>{};

  Grid? _grid;
  PaletteSnapshot? _palette;
  GridScene? _scene;
  GridViewOptions? _options;
  GridPaintStyle? _style;

  /// Сколько блоков построено за всё время (для тестов и профилирования).
  int buildCount = 0;

  /// Сколько блоков лежит в кеше.
  int get cachedBlocks => _blocks.length;

  /// Сообщает кешу, чем рисовать. Если что-то изменилось, готовые блоки сбрасываются.
  void configure({
    required Grid grid,
    required PaletteSnapshot palette,
    required GridScene scene,
    required GridViewOptions options,
    required GridPaintStyle style,
  }) {
    final bool same =
        (identical(_grid, grid) || _grid == grid) &&
        (identical(_palette, palette) || _palette == palette) &&
        _sameScene(scene) &&
        (_options?.sameBaseLayer(options) ?? false) &&
        _style == style;
    _grid = grid;
    _palette = palette;
    _scene = scene;
    _options = options;
    _style = style;
    if (!same) invalidate();
  }

  bool _sameScene(GridScene scene) {
    final GridScene? old = _scene;
    if (old == null) return false;
    return identical(old, scene) ||
        (old.geometry == scene.geometry &&
            old.columns == scene.columns &&
            old.rows == scene.rows &&
            old.pxPerMm == scene.pxPerMm &&
            old.cellSize == scene.cellSize &&
            old.size == scene.size);
  }

  /// Сбрасывает все готовые блоки.
  void invalidate() {
    for (final Picture picture in _blocks.values) {
      picture.dispose();
    }
    _blocks.clear();
    // Знаки рассчитаны под размер ячейки: после смены раскладки их считаем заново.
    for (final TextPainter painter in _symbols.values) {
      painter.dispose();
    }
    _symbols.clear();
  }

  void dispose() {
    invalidate();
  }

  /// Рисует блоки, пересекающие [visible] (прямоугольник в сцене).
  void paintVisible(Canvas canvas, Rect visible) {
    final GridScene? scene = _scene;
    if (scene == null) return;
    final CellRange range = scene.visibleCells(visible);
    if (range.isEmpty) return;
    if (_options?.realistic ?? false) {
      RealisticCells.paintSurface(canvas, visible.intersect(Offset.zero & scene.size), _style!.realistic);
    }
    final int blocksPerRow = _blocksAcross(scene);
    for (int by = range.firstRow ~/ blockSize; by <= range.lastRow ~/ blockSize; by++) {
      for (int bx = range.firstColumn ~/ blockSize; bx <= range.lastColumn ~/ blockSize; bx++) {
        final Picture picture = _blocks[by * blocksPerRow + bx] ??= _build(bx, by);
        canvas.drawPicture(picture);
      }
    }
  }

  int _blocksAcross(GridScene scene) => (scene.columns + blockSize - 1) ~/ blockSize;

  Picture _build(int bx, int by) {
    buildCount++;
    final GridScene scene = _scene!;
    final Grid grid = _grid!;
    final PaletteSnapshot palette = _palette!;
    final GridViewOptions options = _options!;
    final GridPaintStyle style = _style!;

    final int c0 = bx * blockSize;
    final int c1 = math.min(scene.columns, c0 + blockSize);
    final int r0 = by * blockSize;
    final int r1 = math.min(scene.rows, r0 + blockSize);

    final PictureRecorder recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    if (options.realistic) {
      RealisticCells.paintBlock(
        canvas,
        scene: scene,
        grid: grid,
        palette: palette,
        colors: style.realistic,
        material: RealisticMaterial.forMetrics(scene.metrics),
        c0: c0,
        c1: c1,
        r0: r0,
        r1: r1,
      );
      return recorder.endRecording();
    }
    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0
      ..color = style.line;
    final Paint emptyPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0
      ..color = style.emptyCell;
    final Paint fill = Paint();
    final double shortSide = math.min(scene.cellSize.width, scene.cellSize.height);
    final Radius radius = Radius.circular(shortSide * 0.28);

    // 1. Тонкие линии и пустые ячейки.
    for (int row = r0; row < r1; row++) {
      for (int column = c0; column < c1; column++) {
        final Rect cell = scene.cellRect(CellPosition(column, row));
        if (options.showGridLines) canvas.drawRect(cell, linePaint);
        if (grid.at(column, row) == 0 && !options.showGridLines) {
          canvas.drawRect(cell.deflate(shortSide * 0.2), emptyPaint);
        }
      }
    }

    // 2. Бусины.
    for (int row = r0; row < r1; row++) {
      for (int column = c0; column < c1; column++) {
        final int value = grid.at(column, row);
        if (value == 0) continue;
        final PatternColor? color = palette.colorAt(value);
        final Color base = color == null ? style.unknown : Color.fromARGB(255, color.rgb.r, color.rgb.g, color.rgb.b);
        final RRect bead = RRect.fromRectAndRadius(
          scene.cellRect(CellPosition(column, row)).deflate(shortSide * 0.07),
          radius,
        );
        _paintBead(canvas, fill, bead, base, options.showFinish ? BeadFinish.parse(color?.finish) : null);
        if (options.showSymbols && color?.symbol != null) {
          final TextPainter text = _symbol(color!.symbol!, shortSide, base);
          text.paint(canvas, bead.center - Offset(text.width / 2, text.height / 2));
        }
      }
    }

    // 3. Жирные линии «каждая N-я».
    final int every = options.boldEvery;
    if (every > 0) {
      final Paint bold = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, shortSide * 0.09)
        ..color = style.boldLine;
      for (int row = r0; row < r1; row++) {
        for (int column = c0; column < c1; column++) {
          final Rect cell = scene.cellRect(CellPosition(column, row));
          if (column % every == 0) canvas.drawLine(cell.topLeft, cell.bottomLeft, bold);
          if (row % every == 0) canvas.drawLine(cell.topLeft, cell.topRight, bold);
          if (column == scene.columns - 1 && (column + 1) % every == 0) {
            canvas.drawLine(cell.topRight, cell.bottomRight, bold);
          }
          if (row == scene.rows - 1 && (row + 1) % every == 0) canvas.drawLine(cell.bottomLeft, cell.bottomRight, bold);
        }
      }
    }
    return recorder.endRecording();
  }

  void _paintBead(Canvas canvas, Paint paint, RRect bead, Color base, BeadFinish? finish) {
    switch (finish) {
      case BeadFinish.metallic:
        paint.shader = ui.Gradient.linear(
          bead.outerRect.topLeft,
          bead.outerRect.bottomRight,
          <Color>[
            Color.lerp(base, const Color(0xFFFFFFFF), 0.45)!,
            base,
            Color.lerp(base, const Color(0xFF000000), 0.35)!,
          ],
          <double>[0, 0.5, 1],
        );
        canvas.drawRRect(bead, paint);
        paint.shader = null;
      case BeadFinish.transparent:
        paint.color = Color.lerp(base, const Color(0xFFFFFFFF), 0.45)!;
        canvas.drawRRect(bead, paint);
        final Paint ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, bead.shortestSide * 0.12)
          ..color = base;
        canvas.drawRRect(bead.deflate(bead.shortestSide * 0.1), ring);
      case BeadFinish.matte:
      case null:
        paint.color = base;
        canvas.drawRRect(bead, paint);
      case BeadFinish.glossy:
        paint.color = base;
        canvas.drawRRect(bead, paint);
        paint.color = const Color(0x59FFFFFF);
        canvas.drawOval(
          Rect.fromLTWH(
            bead.left + bead.width * 0.2,
            bead.top + bead.height * 0.16,
            bead.width * 0.3,
            bead.height * 0.2,
          ),
          paint,
        );
    }
  }

  TextPainter _symbol(String symbol, double shortSide, Color fill) {
    final Color ink = GridColors.symbolOn(fill);
    final bool darkInk = ink == const Color(0xFF151316);
    return _symbols[(symbol, darkInk)] ??= TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          fontSize: shortSide * 0.62,
          fontWeight: FontWeight.w600,
          color: ink,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }
}
