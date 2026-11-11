import 'dart:math' as math;
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Точка в долях картинки: x слева направо, y сверху вниз, обе от 0 до 1.
final class NormalizedPoint extends Equatable {
  const NormalizedPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  List<Object?> get props => <Object?>[x, y];
}

/// Прямоугольник в долях картинки (оси как у [NormalizedPoint]).
final class NormalizedRect extends Equatable {
  const NormalizedRect({required this.left, required this.top, required this.right, required this.bottom});

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  @override
  List<Object?> get props => <Object?>[left, top, right, bottom];
}

/// Ориентиры лица. «Левый» и «правый» — по картинке (левый — тот, что левее на снимке), а не по лицу.
/// Каждый список — контур или линия точек в порядке обхода; пустой список — ориентир не найден.
final class FaceLandmarks extends Equatable {
  const FaceLandmarks({
    this.leftEye = const <NormalizedPoint>[],
    this.rightEye = const <NormalizedPoint>[],
    this.leftPupil = const <NormalizedPoint>[],
    this.rightPupil = const <NormalizedPoint>[],
    this.leftEyebrow = const <NormalizedPoint>[],
    this.rightEyebrow = const <NormalizedPoint>[],
    this.nose = const <NormalizedPoint>[],
    this.outerLips = const <NormalizedPoint>[],
    this.innerLips = const <NormalizedPoint>[],
  });

  final List<NormalizedPoint> leftEye;
  final List<NormalizedPoint> rightEye;

  /// Зрачок: обычно одна точка, иногда небольшой контур.
  final List<NormalizedPoint> leftPupil;
  final List<NormalizedPoint> rightPupil;
  final List<NormalizedPoint> leftEyebrow;
  final List<NormalizedPoint> rightEyebrow;
  final List<NormalizedPoint> nose;
  final List<NormalizedPoint> outerLips;
  final List<NormalizedPoint> innerLips;

  /// Все ориентиры, которые должна защищать очистка схемы (T54), в одном списке.
  List<List<NormalizedPoint>> get all => <List<NormalizedPoint>>[
    leftEye,
    rightEye,
    leftPupil,
    rightPupil,
    leftEyebrow,
    rightEyebrow,
    nose,
    outerLips,
    innerLips,
  ];

  @override
  List<Object?> get props => all;
}

/// Найденное лицо: рамка и, если Vision их нашёл, ориентиры.
final class DetectedFace extends Equatable {
  const DetectedFace({required this.bounds, this.landmarks = const FaceLandmarks()});

  final NormalizedRect bounds;
  final FaceLandmarks landmarks;

  @override
  List<Object?> get props => <Object?>[bounds, landmarks];
}

/// Результат анализа картинки [width] × [height]. Любая маска может отсутствовать (`null`): платформа без Vision,
/// ошибка запроса, на фото нет объекта.
final class ImageMaskSet extends Equatable {
  ImageMaskSet({
    required this.width,
    required this.height,
    this.subject,
    this.person,
    this.saliency,
    this.faces = const <DetectedFace>[],
  }) {
    if (width < 1) throw ArgumentError.value(width, 'width', 'не меньше 1');
    if (height < 1) throw ArgumentError.value(height, 'height', 'не меньше 1');
    for (final (String name, Uint8List? mask) in <(String, Uint8List?)>[
      ('subject', subject),
      ('person', person),
      ('saliency', saliency),
    ]) {
      if (mask != null && mask.length != width * height) {
        throw ArgumentError.value(mask.length, name, 'ожидалось ${width * height} значений');
      }
    }
  }

  /// Набор без единой маски: так выглядит «Vision недоступен».
  ImageMaskSet.empty({required int width, required int height}) : this(width: width, height: height);

  final int width;
  final int height;

  /// Маска объекта: 0 — фон, остальное — объект (до 255 — степень уверенности). Её же берёт T55 для фона и контура.
  final Uint8List? subject;

  /// Маска человека (запасная для портретов, когда маска объекта захватила лишнее или не нашлась).
  final Uint8List? person;

  /// Значимость: 0 — не привлекает взгляд, 255 — самое заметное. Используется, когда нет ни лиц, ни объекта.
  final Uint8List? saliency;

  final List<DetectedFace> faces;

  bool get isEmpty => subject == null && person == null && saliency == null && faces.isEmpty;

  /// Объект для T55: маска объекта, а если её нет, то маска человека. `null` — объекта нет.
  Uint8List? get subjectOrPerson => subject ?? person;

  /// Пиксели, занятые чертами лица (глаза, зрачки, брови, нос, губы), ненулевые значения. Для защиты клеток в T54.
  /// Рамка лица сюда не входит.
  Uint8List featureMask() {
    final Uint8List mask = Uint8List(width * height);
    for (final DetectedFace face in faces) {
      for (final List<NormalizedPoint> points in face.landmarks.all) {
        _paintPolygon(mask, points, width, height);
      }
    }
    return mask;
  }

  /// Единая маска важности по пикселю: лицо ×[faceWeight], объект ×[subjectWeight], фон ×[backgroundWeight].
  ///
  /// Когда нет ни лиц, ни объекта, веса берутся из значимости: от [backgroundWeight] до [subjectWeight].
  /// Без масок получается `null`: всё одинаково важно, поведение конвейера не меняется.
  Float32List? importance({double faceWeight = 4, double subjectWeight = 2, double backgroundWeight = 0.5}) {
    final Uint8List? object = subjectOrPerson;
    if (object == null && faces.isEmpty && saliency == null) {
      return null;
    }
    final int count = width * height;
    final Float32List weights = Float32List(count);
    for (int i = 0; i < count; i++) {
      final double coverage = object == null ? 0 : (object[i] == 0 ? 0 : 1);
      final double salient = (object == null && saliency != null) ? saliency![i] / 255 : 0;
      weights[i] = backgroundWeight + (subjectWeight - backgroundWeight) * math.max(coverage, salient);
    }
    for (final DetectedFace face in faces) {
      _raiseInRect(weights, face.bounds, faceWeight);
    }
    return weights;
  }

  void _raiseInRect(Float32List weights, NormalizedRect rect, double weight) {
    // Рамку Vision берёт по лицу без лба и волос; запас в десятую часть, чтобы брови и подбородок не остались снаружи.
    final double padX = rect.width * 0.1;
    final double padY = rect.height * 0.1;
    final int x0 = ((rect.left - padX) * width).floor().clamp(0, width);
    final int x1 = ((rect.right + padX) * width).ceil().clamp(0, width);
    final int y0 = ((rect.top - padY) * height).floor().clamp(0, height);
    final int y1 = ((rect.bottom + padY) * height).ceil().clamp(0, height);
    for (int y = y0; y < y1; y++) {
      for (int x = x0; x < x1; x++) {
        final int i = y * width + x;
        weights[i] = math.max(weights[i], weight);
      }
    }
  }

  @override
  List<Object?> get props => <Object?>[width, height, subject, person, saliency, faces];
}

/// Закрашивает многоугольник (или, для одной точки и линии, сами точки и отрезки) значением 255.
void _paintPolygon(Uint8List mask, List<NormalizedPoint> points, int width, int height) {
  if (points.isEmpty) {
    return;
  }
  final List<(double, double)> pts = <(double, double)>[
    for (final NormalizedPoint p in points) (p.x * width, p.y * height),
  ];
  // Линия и точка: рисуем пиксели вдоль отрезков, чтобы тонкий зрачок или бровь не пропали.
  for (int i = 0; i < pts.length; i++) {
    final (double, double) a = pts[i];
    final (double, double) b = pts[(i + 1) % pts.length];
    final int steps = math.max(1, math.max((b.$1 - a.$1).abs(), (b.$2 - a.$2).abs()).ceil());
    for (int s = 0; s <= steps; s++) {
      final double t = s / steps;
      _set(mask, width, height, a.$1 + (b.$1 - a.$1) * t, a.$2 + (b.$2 - a.$2) * t);
    }
  }
  if (pts.length < 3) {
    return;
  }
  double minY = pts.first.$2;
  double maxY = pts.first.$2;
  for (final (double, double) p in pts) {
    minY = math.min(minY, p.$2);
    maxY = math.max(maxY, p.$2);
  }
  for (int y = math.max(0, minY.floor()); y <= math.min(height - 1, maxY.ceil()); y++) {
    final double cy = y + 0.5;
    final List<double> crossings = <double>[];
    for (int i = 0; i < pts.length; i++) {
      final (double, double) a = pts[i];
      final (double, double) b = pts[(i + 1) % pts.length];
      if ((a.$2 <= cy && b.$2 > cy) || (b.$2 <= cy && a.$2 > cy)) {
        crossings.add(a.$1 + (cy - a.$2) / (b.$2 - a.$2) * (b.$1 - a.$1));
      }
    }
    crossings.sort();
    for (int k = 0; k + 1 < crossings.length; k += 2) {
      for (int x = math.max(0, crossings[k].round()); x < math.min(width, crossings[k + 1].round()); x++) {
        mask[y * width + x] = 255;
      }
    }
  }
}

void _set(Uint8List mask, int width, int height, double x, double y) {
  final int px = x.floor();
  final int py = y.floor();
  if (px >= 0 && px < width && py >= 0 && py < height) {
    mask[py * width + px] = 255;
  }
}
