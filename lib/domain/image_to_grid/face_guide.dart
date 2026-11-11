// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes, поле final: класс неизменяемый
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';

/// Лица на фото в виде, удобном стадиям генератора (T54): кожа и черты лица в клетках схемы и в пикселях рабочей
/// картинки.
///
/// Лицо — эллипс, вписанный в рамку Vision (рамка идёт по лицу без лба и волос), минус черты. Все координаты —
/// доли картинки, как в [ImageMaskSet]; сетка схемы покрывает картинку целиком.
final class FaceGuide {
  const FaceGuide(this.masks);

  final ImageMaskSet masks;

  /// Тот же набор масок (по тождеству, без сравнения пикселей) — то же самое лицо: кеш стадий не промахивается.
  @override
  bool operator ==(Object other) => other is FaceGuide && identical(other.masks, masks);

  @override
  int get hashCode => identityHashCode(masks);

  List<DetectedFace> get faces => masks.faces;

  bool get isEmpty => masks.faces.isEmpty;

  /// Пиксели кожи на рабочей картинке [width] × [height]: единицы внутри эллипса лица и вне черт (с запасом в
  /// пиксель маски черт, чтобы тени у глаз и губ не попали в кожу).
  Uint8List skinPixels(int width, int height) {
    final Uint8List out = Uint8List(width * height);
    final Uint8List features = _dilate(masks.featureMask(), masks.width, masks.height);
    for (final DetectedFace face in faces) {
      final NormalizedRect r = face.bounds;
      final int x0 = (r.left * width).floor().clamp(0, width);
      final int x1 = (r.right * width).ceil().clamp(0, width);
      final int y0 = (r.top * height).floor().clamp(0, height);
      final int y1 = (r.bottom * height).ceil().clamp(0, height);
      for (int y = y0; y < y1; y++) {
        for (int x = x0; x < x1; x++) {
          final double nx = (x + 0.5) / width;
          final double ny = (y + 0.5) / height;
          if (!_inEllipse(r, nx, ny)) continue;
          final int mx = math.min(masks.width - 1, (nx * masks.width).floor());
          final int my = math.min(masks.height - 1, (ny * masks.height).floor());
          if (features[my * masks.width + mx] != 0) continue;
          out[y * width + x] = 1;
        }
      }
    }
    return out;
  }

  /// Клетки схемы, к которым относятся лица. [workWidth] × [workHeight] — размер рабочей картинки, в которой
  /// заданы [regions].
  FaceCells cells(CellRegions regions, {required int workWidth, required int workHeight}) {
    final int count = regions.columns * regions.rows;
    final Uint8List skin = Uint8List(count);
    final Uint8List feature = Uint8List(count);
    final Uint8List features = masks.featureMask();
    final Set<int> pupils = <int>{};
    final Set<int> lips = <int>{};
    final List<List<int>> eyes = <List<int>>[];

    int cellAt(double x, double y) {
      final int px = (x * workWidth).floor().clamp(0, workWidth - 1);
      final int py = (y * workHeight).floor().clamp(0, workHeight - 1);
      // Ищем клетку по прямоугольникам: сетка маленькая, а точек черт десятки.
      for (int c = 0; c < count; c++) {
        if (px >= regions.left(c) && px < regions.right(c) && py >= regions.top(c) && py < regions.bottom(c)) return c;
      }
      return -1;
    }

    for (final DetectedFace face in faces) {
      final NormalizedRect r = face.bounds;
      for (int c = 0; c < count; c++) {
        final double cx = (regions.left(c) + regions.right(c)) / 2 / workWidth;
        final double cy = (regions.top(c) + regions.bottom(c)) / 2 / workHeight;
        if (cx < r.left || cx > r.right || cy < r.top || cy > r.bottom) continue;
        if (_inEllipse(r, cx, cy)) skin[c] = 1;
        if (_hasFeaturePixel(features, regions, c, workWidth, workHeight)) feature[c] = 1;
      }
      final FaceLandmarks marks = face.landmarks;
      for (final List<NormalizedPoint> points in marks.all) {
        for (final NormalizedPoint p in _densify(points)) {
          final int c = cellAt(p.x, p.y);
          if (c >= 0) feature[c] = 1;
        }
      }
      for (final List<NormalizedPoint> eye in <List<NormalizedPoint>>[marks.leftPupil, marks.rightPupil]) {
        for (final NormalizedPoint p in eye.isEmpty ? const <NormalizedPoint>[] : <NormalizedPoint>[_centroid(eye)]) {
          final int c = cellAt(p.x, p.y);
          if (c >= 0) pupils.add(c);
        }
      }
      if (marks.leftPupil.isEmpty) _eyeCentre(marks.leftEye, cellAt, pupils);
      if (marks.rightPupil.isEmpty) _eyeCentre(marks.rightEye, cellAt, pupils);
      for (final (List<NormalizedPoint> contour, List<NormalizedPoint> pupil)
          in <(List<NormalizedPoint>, List<NormalizedPoint>)>[
            (marks.leftEye, marks.leftPupil),
            (marks.rightEye, marks.rightPupil),
          ]) {
        final Set<int> own = <int>{};
        for (final NormalizedPoint p in <NormalizedPoint>[..._densify(contour), ...pupil]) {
          final int c = cellAt(p.x, p.y);
          if (c >= 0) own.add(c);
        }
        if (own.isNotEmpty) eyes.add(own.toList()..sort());
      }
      final List<NormalizedPoint> mouth = marks.innerLips.isNotEmpty ? marks.innerLips : marks.outerLips;
      for (final NormalizedPoint p in _densify(mouth)) {
        final int c = cellAt(p.x, p.y);
        if (c >= 0) lips.add(c);
      }
    }
    for (int c = 0; c < count; c++) {
      if (feature[c] == 1) skin[c] = 0;
    }
    for (final int c in <int>[...pupils, ...lips]) {
      feature[c] = 1;
      skin[c] = 0;
    }
    return FaceCells(
      columns: regions.columns,
      rows: regions.rows,
      skin: skin,
      feature: feature,
      pupils: (pupils.toList()..sort()),
      eyes: eyes,
      lips: (lips.toList()..sort()),
    );
  }

  void _eyeCentre(List<NormalizedPoint> eye, int Function(double, double) cellAt, Set<int> pupils) {
    if (eye.isEmpty) return;
    final NormalizedPoint c = _centroid(eye);
    final int cell = cellAt(c.x, c.y);
    if (cell >= 0) pupils.add(cell);
  }

  static bool _inEllipse(NormalizedRect r, double x, double y) {
    final double rx = r.width / 2;
    final double ry = r.height / 2;
    if (rx <= 0 || ry <= 0) return false;
    final double dx = (x - (r.left + rx)) / rx;
    final double dy = (y - (r.top + ry)) / ry;
    return dx * dx + dy * dy <= 1;
  }

  bool _hasFeaturePixel(Uint8List features, CellRegions regions, int cell, int workWidth, int workHeight) =>
      // Маска черт задана в размере исходной картинки; клетка в её пикселях — тот же прямоугольник в долях.
      _rectHasPixel(
        features,
        masks.width,
        masks.height,
        regions.left(cell) / workWidth,
        regions.top(cell) / workHeight,
        regions.right(cell) / workWidth,
        regions.bottom(cell) / workHeight,
      );

  static bool _rectHasPixel(Uint8List mask, int width, int height, double l, double t, double r, double b) {
    final int x0 = (l * width).floor().clamp(0, width - 1);
    final int x1 = math.max(x0 + 1, (r * width).ceil()).clamp(1, width);
    final int y0 = (t * height).floor().clamp(0, height - 1);
    final int y1 = math.max(y0 + 1, (b * height).ceil()).clamp(1, height);
    for (int y = y0; y < y1; y++) {
      for (int x = x0; x < x1; x++) {
        if (mask[y * width + x] != 0) return true;
      }
    }
    return false;
  }
}

/// Лица в клетках схемы.
final class FaceCells {
  const FaceCells({
    required this.columns,
    required this.rows,
    required this.skin,
    required this.feature,
    required this.pupils,
    required this.lips,
    this.eyes = const <List<int>>[],
  });

  final int columns;
  final int rows;

  /// 1 — клетка кожи: внутри лица и вне черт. Её цвет берётся только из нескольких цветов кожи.
  final Uint8List skin;

  /// 1 — клетка черты лица (глаз, зрачок, бровь, нос, губы): очистка её не трогает.
  final Uint8List feature;

  /// Клетки зрачков: по самому тёмному из нескольких лучших цветов.
  final List<int> pupils;

  /// Клетки линии губ: по самому насыщенному из нескольких лучших цветов.
  final List<int> lips;

  /// Клетки каждого глаза (контур и зрачок): в каждом должна остаться хотя бы одна тёмная клетка.
  final List<List<int>> eyes;

  bool isFeature(int cell) => feature[cell] != 0;
  bool isSkin(int cell) => skin[cell] != 0;
  bool get hasSkin => skin.any((v) => v != 0);
}

NormalizedPoint _centroid(List<NormalizedPoint> points) {
  double x = 0;
  double y = 0;
  for (final NormalizedPoint p in points) {
    x += p.x;
    y += p.y;
  }
  return NormalizedPoint(x / points.length, y / points.length);
}

/// Добавляет точки вдоль отрезков между соседними точками, чтобы тонкая линия задела каждую клетку на пути.
List<NormalizedPoint> _densify(List<NormalizedPoint> points) {
  if (points.length < 2) return points;
  final List<NormalizedPoint> out = <NormalizedPoint>[];
  for (int i = 0; i < points.length - 1; i++) {
    final NormalizedPoint a = points[i];
    final NormalizedPoint b = points[i + 1];
    for (int s = 0; s < 16; s++) {
      final double t = s / 16;
      out.add(NormalizedPoint(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t));
    }
  }
  out.add(points.last);
  return out;
}

Uint8List _dilate(Uint8List mask, int width, int height) {
  final Uint8List out = Uint8List.fromList(mask);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      if (mask[y * width + x] == 0) continue;
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          final int nx = x + dx;
          final int ny = y + dy;
          if (nx >= 0 && nx < width && ny >= 0 && ny < height) out[ny * width + nx] = 255;
        }
      }
    }
  }
  return out;
}
