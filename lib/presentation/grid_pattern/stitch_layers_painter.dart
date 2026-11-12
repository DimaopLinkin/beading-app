import 'dart:math' as math;
import 'dart:ui';

import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:beading/domain/stitch/point_stitch.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/presentation/grid_pattern/grid_colors.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/grid_pattern/stitch_cells.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/rendering.dart';

/// Всё, от чего зависит рисунок слоёв вышивки, кроме самих слоёв: подложка, вид, подсветка, скрытые слои.
final class StitchLayersStyle {
  const StitchLayersStyle({
    required this.surface,
    required this.unknown,
    this.realistic = false,
    this.hiddenLayers = const <StitchLayerKind>{},
    this.highlightColor,
    this.beadColors = const <CatalogRef, Color>{},
  });

  /// Цвет канвы: от него зависит цвет каймы вокруг стежков и притушение.
  final Color surface;

  /// Цвет стежка, чьего цвета нет в палитре.
  final Color unknown;

  /// Вид «как будет выглядеть»: стежки с тенью.
  final bool realistic;

  final Set<StitchLayerKind> hiddenLayers;

  /// Значение сетки подсвеченного цвета; остальные стежки притушены.
  final int? highlightColor;

  /// Цвет бусин слоя по позиции каталога бисера; бусина без цвета рисуется нейтральной жемчужной.
  final Map<CatalogRef, Color> beadColors;

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, поля final
  bool operator ==(Object other) =>
      other is StitchLayersStyle &&
      other.surface == surface &&
      other.unknown == unknown &&
      other.realistic == realistic &&
      other.highlightColor == highlightColor &&
      mapEquals(other.beadColors, beadColors) &&
      other.hiddenLayers.length == hiddenLayers.length &&
      other.hiddenLayers.containsAll(hiddenLayers);

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, см. выше
  int get hashCode => Object.hash(
    surface,
    unknown,
    realistic,
    highlightColor,
    Object.hashAllUnordered(hiddenLayers),
    Object.hashAllUnordered(beadColors.entries.map((e) => Object.hash(e.key, e.value))),
  );
}

/// Рисование слоёв вышивки поверх клеток: неполные крестики, бэкстич и прямые стежки, узелки и бусины.
///
/// Чистые функции над `Canvas`. Узлы полушаговой решётки (`x`, `y`) переводятся в сцену как половины клетки, поэтому
/// слои рисуются только для прямоугольной раскладки, как и вышивка.
abstract final class StitchLayersPaint {
  static void paint(
    Canvas canvas, {
    required GridScene scene,
    required StitchLayers layers,
    required PaletteSnapshot palette,
    required StitchLayersStyle style,
  }) {
    final Offset origin = scene.cellRect(const CellPosition(0, 0)).topLeft;
    final Size cell = scene.cellSize;
    final double s = math.min(cell.width, cell.height);
    Offset at(LatticeNode node) => origin + Offset(node.x * cell.width / 2, node.y * cell.height / 2);
    final Paint paint = Paint()..isAntiAlias = true;

    Color colorOf(int value) {
      final PatternColor? color = palette.colorAt(value);
      final Color base = color == null ? style.unknown : Color.fromARGB(255, color.rgb.r, color.rgb.g, color.rgb.b);
      final int? highlight = style.highlightColor;
      return highlight != null && highlight != value ? StitchCells.dim(base, style.surface) : base;
    }

    if (!style.hiddenLayers.contains(StitchLayerKind.partials)) {
      for (final PartialStitch p in layers.partials) {
        final Rect rect = scene.cellRect(p.cell);
        final double width = s * StitchCells.strandWidth(layers.specFor(p.color).crossStrands) * 0.75;
        _partial(canvas, paint, rect, p, colorOf(p.color), width, style);
      }
    }
    if (!style.hiddenLayers.contains(StitchLayerKind.lines)) {
      for (final LineStitch l in layers.lines) {
        final double strands = layers.specFor(l.color).backstitchStrands.toDouble();
        final double width = math.max(1, s * (0.06 + 0.03 * strands));
        _line(canvas, paint, at(l.from), at(l.to), colorOf(l.color), width, style, s);
      }
    }
    if (!style.hiddenLayers.contains(StitchLayerKind.points)) {
      for (final PointStitch p in layers.points) {
        final Offset center = at(p.node);
        if (p.kind == PointKind.bead) {
          _bead(canvas, paint, center, s * 0.18, style, style.beadColors[p.bead]);
        } else {
          _knot(canvas, paint, center, s * (0.13 + 0.035 * p.wraps), colorOf(p.color), style);
        }
      }
    }
  }

  /// Каймы вокруг стежка, чтобы он читался на заливке своего же цвета: светлая вокруг тёмного, тёмная вокруг светлого.
  static Color halo(Color stitch) =>
      (GridColors.symbolOn(stitch) == const Color(0xFFFFFFFF) ? const Color(0xFFFFFFFF) : const Color(0xFF000000))
          .withValues(alpha: 0.55);

  static void _stroke(
    Canvas canvas,
    Paint paint,
    Offset from,
    Offset to,
    Color color,
    double width,
    StitchLayersStyle style,
    double s,
  ) {
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (style.realistic) {
      paint
        ..strokeWidth = width
        ..color = const Color(0xFF000000).withValues(alpha: 0.24);
      canvas.drawLine(from + Offset(s * 0.03, s * 0.045), to + Offset(s * 0.03, s * 0.045), paint);
    } else {
      paint
        ..strokeWidth = width + s * 0.07
        ..color = halo(color);
      canvas.drawLine(from, to, paint);
    }
    paint
      ..strokeWidth = width
      ..color = color;
    canvas.drawLine(from, to, paint);
  }

  static void _line(
    Canvas canvas,
    Paint paint,
    Offset from,
    Offset to,
    Color color,
    double width,
    StitchLayersStyle style,
    double s,
  ) => _stroke(canvas, paint, from, to, color, width, style, s);

  static Offset _corner(Rect r, StitchOrientation o) => switch (o) {
    StitchOrientation.topLeft => r.topLeft,
    StitchOrientation.topRight => r.topRight,
    StitchOrientation.bottomLeft => r.bottomLeft,
    StitchOrientation.bottomRight => r.bottomRight,
    StitchOrientation.slash => r.bottomLeft,
    StitchOrientation.backslash => r.topLeft,
  };

  static void _partial(
    Canvas canvas,
    Paint paint,
    Rect cell,
    PartialStitch p,
    Color color,
    double width,
    StitchLayersStyle style,
  ) {
    final double s = math.min(cell.width, cell.height);
    final Rect r = cell.deflate(s * 0.12);
    void stroke(Offset a, Offset b) => _stroke(canvas, paint, a, b, color, width, style, s);
    switch (p.kind) {
      case PartialKind.half:
      case PartialKind.tent:
        if (p.orientation == StitchOrientation.slash) {
          stroke(r.bottomLeft, r.topRight);
        } else {
          stroke(r.topLeft, r.bottomRight);
        }
      case PartialKind.quarter:
        stroke(_corner(r, p.orientation), r.center);
      case PartialKind.threeQuarter:
        // Полная диагональ не проходит через угол, и от самого угла идёт четверть до центра.
        final bool cornerOnBackslash =
            p.orientation == StitchOrientation.topLeft || p.orientation == StitchOrientation.bottomRight;
        if (cornerOnBackslash) {
          stroke(r.bottomLeft, r.topRight);
        } else {
          stroke(r.topLeft, r.bottomRight);
        }
        stroke(_corner(r, p.orientation), r.center);
      case PartialKind.petit:
        // Маленький крестик в четверти клетки у угла.
        final Offset corner = _corner(r, p.orientation);
        final Offset toCenter = r.center - corner;
        final Rect quarter = Rect.fromPoints(corner, corner + toCenter).deflate(s * 0.04);
        stroke(quarter.bottomLeft, quarter.topRight);
        stroke(quarter.topLeft, quarter.bottomRight);
    }
  }

  static void _knot(Canvas canvas, Paint paint, Offset center, double radius, Color color, StitchLayersStyle style) {
    paint
      ..shader = null
      ..style = PaintingStyle.fill;
    if (style.realistic) {
      paint.color = const Color(0xFF000000).withValues(alpha: 0.26);
      canvas.drawCircle(center + Offset(radius * 0.2, radius * 0.3), radius, paint);
    } else {
      paint.color = halo(color);
      canvas.drawCircle(center, radius * 1.22, paint);
    }
    paint.color = color;
    canvas.drawCircle(center, radius, paint);
    paint.color = const Color(0xFFFFFFFF).withValues(alpha: 0.35);
    canvas.drawCircle(center + Offset(-radius * 0.28, -radius * 0.3), radius * 0.3, paint);
  }

  /// Бусина с отверстием. Цвет берётся у позиции каталога бисера; если он неизвестен (каталог не загружен), бусина
  /// нейтральная жемчужная.
  static void _bead(
    Canvas canvas,
    Paint paint,
    Offset center,
    double radius,
    StitchLayersStyle style,
    Color? color,
  ) {
    paint
      ..shader = null
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF000000).withValues(alpha: 0.3);
    canvas.drawCircle(center + Offset(radius * 0.15, radius * 0.25), radius * 1.1, paint);
    paint.color = color ?? const Color(0xFFEDE8E0);
    canvas.drawCircle(center, radius, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, radius * 0.18)
      ..color = const Color(0xFF8C867C);
    canvas.drawCircle(center, radius, paint);
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF8C867C);
    canvas.drawCircle(center, radius * 0.28, paint);
  }
}

/// Кеш слоя вышивки: вся картинка слоёв одним `Picture`, пересобирается, только когда изменились слои, палитра,
/// сцена или вид. Перерисовка при зуме и сдвиге ничего не пересобирает ([buildCount] не растёт).
final class StitchLayerCache {
  Picture? _picture;
  StitchLayers? _layers;
  PaletteSnapshot? _palette;
  GridScene? _scene;
  StitchLayersStyle? _style;

  /// Сколько раз слой пересобирали (для тестов и профилирования).
  int buildCount = 0;

  /// Возвращает `true`, если готовая картинка слоёв сброшена и painter должен перерисоваться.
  bool configure({
    required StitchLayers layers,
    required PaletteSnapshot palette,
    required GridScene scene,
    required StitchLayersStyle style,
  }) {
    final bool sameScene =
        _scene != null &&
        (identical(_scene, scene) ||
            (_scene!.pxPerMm == scene.pxPerMm &&
                _scene!.columns == scene.columns &&
                _scene!.rows == scene.rows &&
                _scene!.metrics == scene.metrics &&
                _scene!.geometry == scene.geometry));
    final bool same =
        sameScene &&
        _style == style &&
        (identical(_layers, layers) || _layers == layers) &&
        (identical(_palette, palette) || _palette == palette);
    if (!same) invalidate();
    _layers = layers;
    _palette = palette;
    _scene = scene;
    _style = style;
    return !same;
  }

  void invalidate() {
    _picture?.dispose();
    _picture = null;
  }

  void dispose() => invalidate();

  void paint(Canvas canvas) {
    final StitchLayers? layers = _layers;
    if (layers == null || layers.isEmpty) return;
    final Picture picture = _picture ??= _build();
    canvas.drawPicture(picture);
  }

  Picture _build() {
    buildCount++;
    final PictureRecorder recorder = PictureRecorder();
    StitchLayersPaint.paint(
      Canvas(recorder),
      scene: _scene!,
      layers: _layers!,
      palette: _palette!,
      style: _style!,
    );
    return recorder.endRecording();
  }
}

/// Слой вышивки на схеме: рисует кеш, ничего не считает сам.
class StitchLayersPainter extends CustomPainter {
  StitchLayersPainter({required this.cache, required this.revision});

  final StitchLayerCache cache;

  /// Растёт при каждой смене данных слоя: по нему painter понимает, что кеш сбросили.
  final int revision;

  @override
  void paint(Canvas canvas, Size size) => cache.paint(canvas);

  @override
  bool shouldRepaint(StitchLayersPainter oldDelegate) => oldDelegate.cache != cache || oldDelegate.revision != revision;
}
