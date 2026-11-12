import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Один мазок маркера. Координаты и толщина — в долях ширины страницы (так мазок не зависит от размера экрана
/// и от масштаба картинки): `x` и `y` обе делятся на ширину, поэтому отношение сторон страницы сохраняется.
final class MarkerStroke extends Equatable {
  MarkerStroke({required this.rgb, required this.width, required List<double> points})
    : assert(points.length >= 2 && points.length.isEven, 'в мазке хотя бы одна точка: пары x, y'),
      points = Float32List.fromList(points);

  /// Цвет `0xRRGGBB`; прозрачность задаёт отрисовка.
  final int rgb;

  /// Толщина линии, доля ширины страницы.
  final double width;

  /// Пары `x, y` подряд.
  final Float32List points;

  int get pointCount => points.length ~/ 2;

  /// Расстояние от точки `(x, y)` до ближайшей точки мазка с учётом половины толщины: ластик задевает мазок,
  /// если его круг [radius] пересекает линию.
  bool touches(double x, double y, double radius) {
    final double reach = radius + width / 2;
    final double limit = reach * reach;
    if (pointCount == 1) {
      return _sq(points[0] - x, points[1] - y) <= limit;
    }
    for (int i = 0; i + 3 < points.length; i += 2) {
      if (_segmentDistanceSquared(x, y, points[i], points[i + 1], points[i + 2], points[i + 3]) <= limit) {
        return true;
      }
    }
    return false;
  }

  static double _sq(double dx, double dy) => dx * dx + dy * dy;

  static double _segmentDistanceSquared(double px, double py, double ax, double ay, double bx, double by) {
    final double dx = bx - ax;
    final double dy = by - ay;
    final double length = dx * dx + dy * dy;
    final double t = length == 0 ? 0 : (((px - ax) * dx + (py - ay) * dy) / length).clamp(0.0, 1.0);
    return _sq(px - (ax + t * dx), py - (ay + t * dy));
  }

  @override
  List<Object?> get props => <Object?>[rgb, width, points];
}

/// Пометки маркером на одной странице схемы из книги.
final class PageMarkup extends Equatable {
  PageMarkup([Iterable<MarkerStroke> strokes = const <MarkerStroke>[]])
    : strokes = List<MarkerStroke>.unmodifiable(strokes);

  const PageMarkup.empty() : strokes = const <MarkerStroke>[];

  /// Мазки снизу вверх: поздний лежит поверх раннего.
  final List<MarkerStroke> strokes;

  bool get isEmpty => strokes.isEmpty;

  PageMarkup withStroke(MarkerStroke stroke) => PageMarkup(<MarkerStroke>[...strokes, stroke]);

  /// Без мазков, которых касается круг ластика [radius] в точках пути `points` (пары `x, y`).
  PageMarkup erasing(List<double> points, double radius) {
    final List<MarkerStroke> kept = <MarkerStroke>[
      for (final MarkerStroke s in strokes)
        if (!_touchedAny(s, points, radius)) s,
    ];
    return kept.length == strokes.length ? this : PageMarkup(kept);
  }

  static bool _touchedAny(MarkerStroke stroke, List<double> points, double radius) {
    for (int i = 0; i + 1 < points.length; i += 2) {
      if (stroke.touches(points[i], points[i + 1], radius)) return true;
    }
    return false;
  }

  @override
  List<Object?> get props => <Object?>[strokes];
}

/// Цвета и толщины маркера для панели.
abstract final class MarkerPalette {
  /// Жёлтый, розовый, голубой, зелёный, оранжевый: яркие, но под прозрачностью не заслоняют схему.
  static const List<int> colors = <int>[0xFFE45C, 0xFF8FB8, 0x7CC8FF, 0x8EE08A, 0xFFB066];

  /// Тонкий, средний и широкий, доля ширины страницы.
  static const List<double> widths = <double>[0.006, 0.012, 0.024];

  /// Радиус ластика относительно толщины маркера.
  static const double eraserScale = 1.5;
}

/// Хранение мазков в двоичном виде: версия, число мазков, у мазка цвет, толщина, число точек и пары `x, y`.
abstract final class PageMarkupCodec {
  static const int version = 1;

  /// Предел мазков и точек, чтобы битый файл не выделил гигабайты.
  static const int maxStrokes = 20000;
  static const int maxPointsPerStroke = 200000;

  static Uint8List encode(PageMarkup markup) {
    int size = 5;
    for (final MarkerStroke s in markup.strokes) {
      size += 12 + s.points.length * 4;
    }
    final ByteData out = ByteData(size);
    int at = 0;
    out.setUint8(at++, version);
    out.setUint32(at, markup.strokes.length, Endian.little);
    at += 4;
    for (final MarkerStroke s in markup.strokes) {
      out.setUint32(at, s.rgb, Endian.little);
      out.setFloat32(at + 4, s.width, Endian.little);
      out.setUint32(at + 8, s.pointCount, Endian.little);
      at += 12;
      for (final double v in s.points) {
        out.setFloat32(at, v, Endian.little);
        at += 4;
      }
    }
    return out.buffer.asUint8List();
  }

  /// `null`, если байты не разбираются: пометки теряются, а страница открывается.
  static PageMarkup? decode(Uint8List bytes) {
    try {
      if (bytes.isEmpty) return const PageMarkup.empty();
      final ByteData data = ByteData.sublistView(bytes);
      if (data.getUint8(0) != version) return null;
      final int count = data.getUint32(1, Endian.little);
      if (count > maxStrokes) return null;
      int at = 5;
      final List<MarkerStroke> strokes = <MarkerStroke>[];
      for (int i = 0; i < count; i++) {
        final int rgb = data.getUint32(at, Endian.little);
        final double width = data.getFloat32(at + 4, Endian.little);
        final int points = data.getUint32(at + 8, Endian.little);
        at += 12;
        if (points < 1 || points > maxPointsPerStroke || at + points * 8 > bytes.length || !width.isFinite) {
          return null;
        }
        final List<double> xy = <double>[
          for (int k = 0; k < points * 2; k++) data.getFloat32(at + k * 4, Endian.little),
        ];
        at += points * 8;
        if (xy.any((v) => !v.isFinite)) return null;
        strokes.add(MarkerStroke(rgb: rgb & 0xFFFFFF, width: width, points: xy));
      }
      return PageMarkup(strokes);
    } on RangeError {
      return null;
    }
  }
}
