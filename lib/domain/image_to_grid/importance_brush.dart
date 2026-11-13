import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:equatable/equatable.dart';

/// Как картинка для конвейера получена из исходной: поворот и обрезка, плюс её размер в пикселях.
///
/// Мазки кисти «важное» хранятся в долях исходной картинки и поэтому переживают поворот и обрезку:
/// [toPrepared] и [toSource] переводят точку между исходной и подготовленной картинкой.
final class PreparedFrame extends Equatable {
  const PreparedFrame({required this.width, required this.height, this.quarterTurns = 0, this.crop = CropRect.full});

  final int width;
  final int height;

  /// Поворот по часовой стрелке, четвертей оборота.
  final int quarterTurns;
  final CropRect crop;

  /// Короткая сторона всей повёрнутой картинки (до обрезки) в пикселях подготовленной: единица толщины кисти.
  double get shortSide => math.min(width / crop.width, height / crop.height);

  /// Точка исходной картинки (доли) → точка подготовленной (доли, может выйти за 0…1, если её обрезали).
  (double, double) toPrepared(double x, double y) {
    double rx = x;
    double ry = y;
    for (int i = 0; i < quarterTurns % 4; i++) {
      final double nx = 1 - ry;
      ry = rx;
      rx = nx;
    }
    return ((rx - crop.left) / crop.width, (ry - crop.top) / crop.height);
  }

  /// Обратный перевод: точка подготовленной картинки (доли) → точка исходной (доли).
  (double, double) toSource(double x, double y) {
    double rx = crop.left + x * crop.width;
    double ry = crop.top + y * crop.height;
    for (int i = 0; i < quarterTurns % 4; i++) {
      final double nx = ry;
      ry = 1 - rx;
      rx = nx;
    }
    return (rx, ry);
  }

  @override
  List<Object?> get props => <Object?>[width, height, quarterTurns, crop];
}

/// Мазок кисти: [points] — пары `x, y` в долях исходной картинки, [radius] — в короткой стороне повёрнутой картинки.
final class BrushStroke extends Equatable {
  const BrushStroke({required this.points, required this.radius});

  final List<double> points;
  final double radius;

  @override
  List<Object?> get props => <Object?>[radius, points];
}

/// Мазки пользователя по картинке: «важное» для генератора (T60).
final class ImportanceBrush extends Equatable {
  const ImportanceBrush([this.strokes = const <BrushStroke>[]]);

  static const ImportanceBrush empty = ImportanceBrush();

  /// Вес пикселя под мазком: как у найденного лица, выше объекта.
  static const double weight = 4;

  final List<BrushStroke> strokes;

  bool get isEmpty => strokes.isEmpty;

  ImportanceBrush withStroke(BrushStroke stroke) => ImportanceBrush(<BrushStroke>[...strokes, stroke]);

  /// Без мазков, которых касается круг ластика радиуса [radius] (в коротких сторонах) в точках [points]
  /// (пары `x, y` в долях подготовленной картинки).
  ImportanceBrush erasing(List<double> points, double radius, PreparedFrame frame) {
    final double r = radius * frame.shortSide;
    final List<BrushStroke> kept = <BrushStroke>[
      for (final BrushStroke s in strokes)
        if (!_touches(s, points, r + s.radius * frame.shortSide, frame)) s,
    ];
    return kept.length == strokes.length ? this : ImportanceBrush(kept);
  }

  bool _touches(BrushStroke stroke, List<double> points, double reach, PreparedFrame frame) {
    final List<(double, double)> pts = <(double, double)>[
      for (int i = 0; i + 1 < stroke.points.length; i += 2) _px(stroke.points[i], stroke.points[i + 1], frame),
    ];
    for (int i = 0; i + 1 < points.length; i += 2) {
      final double ex = points[i] * frame.width;
      final double ey = points[i + 1] * frame.height;
      for (int k = 0; k < pts.length; k++) {
        final (double, double) a = pts[k];
        final (double, double) b = k + 1 < pts.length ? pts[k + 1] : a;
        if (_segmentDistance(ex, ey, a, b) <= reach) {
          return true;
        }
      }
    }
    return false;
  }

  /// Поднимает [weights] (по пикселю подготовленной картинки) до [weight] под мазками. `null` — «все одинаково
  /// важны» (вес 1). Без мазков возвращает [weights] как есть.
  Float32List? applyTo(Float32List? weights, PreparedFrame frame) {
    if (strokes.isEmpty) {
      return weights;
    }
    final int w = frame.width;
    final int h = frame.height;
    final Float32List out = weights == null
        ? (Float32List(w * h)..fillRange(0, w * h, 1))
        : Float32List.fromList(weights);
    for (final BrushStroke stroke in strokes) {
      final double r = math.max(0.5, stroke.radius * frame.shortSide);
      final List<(double, double)> pts = <(double, double)>[
        for (int i = 0; i + 1 < stroke.points.length; i += 2) _px(stroke.points[i], stroke.points[i + 1], frame),
      ];
      for (int k = 0; k < pts.length; k++) {
        final (double, double) a = pts[k];
        final (double, double) b = k + 1 < pts.length ? pts[k + 1] : a;
        final int x0 = (math.min(a.$1, b.$1) - r).floor().clamp(0, w);
        final int x1 = (math.max(a.$1, b.$1) + r).ceil().clamp(0, w);
        final int y0 = (math.min(a.$2, b.$2) - r).floor().clamp(0, h);
        final int y1 = (math.max(a.$2, b.$2) + r).ceil().clamp(0, h);
        for (int y = y0; y < y1; y++) {
          for (int x = x0; x < x1; x++) {
            if (_segmentDistance(x + 0.5, y + 0.5, a, b) <= r) {
              final int i = y * w + x;
              if (out[i] < weight) {
                out[i] = weight;
              }
            }
          }
        }
      }
    }
    return out;
  }

  static (double, double) _px(double x, double y, PreparedFrame frame) {
    final (double, double) p = frame.toPrepared(x, y);
    return (p.$1 * frame.width, p.$2 * frame.height);
  }

  static double _segmentDistance(double px, double py, (double, double) a, (double, double) b) {
    final double dx = b.$1 - a.$1;
    final double dy = b.$2 - a.$2;
    final double len2 = dx * dx + dy * dy;
    final double t = len2 == 0 ? 0 : (((px - a.$1) * dx + (py - a.$2) * dy) / len2).clamp(0.0, 1.0);
    final double cx = a.$1 + dx * t;
    final double cy = a.$2 + dy * t;
    return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
  }

  @override
  List<Object?> get props => <Object?>[strokes];
}
