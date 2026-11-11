import 'dart:typed_data';

import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/cell_labeler.dart';
import 'package:beading/domain/image_to_grid/face_guide.dart';
import 'package:beading/domain/image_to_grid/image_prefilter.dart';
import 'package:beading/domain/image_to_grid/label_smoother.dart';
import 'package:beading/domain/image_to_grid/palette_builder.dart';
import 'package:beading/domain/image_to_grid/palette_constraint.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';

/// Все входные данные конвейера «картинка → схема».
final class ImageToGridRequest {
  ImageToGridRequest({
    required this.image,
    required this.geometry,
    required this.metrics,
    required this.columns,
    required this.rows,
    required this.maxColors,
    this.constraint = const PaletteConstraint.free(),
    this.importance,
    this.dither = false,
    this.seed = 0,
    this.prefilter,
    this.paletteBuilder,
    this.labeler,
    this.smoother,
    this.refillFreedColors = false,
    this.faces,
    this.draft = false,
    this.steps = const <PatternStep>[],
  }) {
    if (columns < 1 || columns > Grid.maxSide) throw ArgumentError.value(columns, 'columns', 'от 1 до ${Grid.maxSide}');
    if (rows < 1 || rows > Grid.maxSide) throw ArgumentError.value(rows, 'rows', 'от 1 до ${Grid.maxSide}');
    if (maxColors < 1 || maxColors > PaletteSnapshot.maxColors) {
      throw ArgumentError.value(maxColors, 'maxColors', 'от 1 до ${PaletteSnapshot.maxColors}');
    }
    final Float32List? weights = importance;
    if (weights != null) {
      if (weights.length != image.width * image.height) {
        throw ArgumentError.value(weights.length, 'importance', 'ожидалось ${image.width * image.height} весов');
      }
      for (final double w in weights) {
        if (!w.isFinite || w < 0) throw ArgumentError.value(w, 'importance', 'вес — конечное число не меньше нуля');
      }
    }
    final List<Object?>? candidates = constraint.candidates;
    if (candidates != null && candidates.isEmpty) {
      throw ArgumentError.value(constraint, 'constraint', 'в списке допустимых цветов пусто');
    }
  }

  final SourceImage image;
  final GridGeometry geometry;
  final CellMetrics metrics;
  final int columns;
  final int rows;

  /// Сколько цветов в схеме самое большее.
  final int maxColors;

  final PaletteConstraint constraint;

  /// Маска важности: вес на пиксель картинки, ряды сверху вниз. `null` — все пиксели одинаково важны.
  final Float32List? importance;

  final bool dither;

  /// Зерно для единственного случайного выбора в квантовании: один вход и одно зерно дают один результат.
  final int seed;

  /// Подготовка фото перед выбором цветов (стадия 1). `null` — без фильтра: цвет ячейки берётся прямо из картинки.
  final ImagePrefilter? prefilter;

  /// Стадия 2: палитра по рабочим пикселям. Вместе с [labeler] включает «пиксельный» путь конвейера (цвет клетки
  /// голосованием, `CellCosts` для шагов); без обоих работает путь T24 «средний цвет клетки → k-means».
  final PaletteBuilder? paletteBuilder;

  /// Стадия 3: цены цветов и начальная разметка клеток. См. [paletteBuilder].
  final CellLabeler? labeler;

  /// Дизеринг пиксельный путь не применяет: цвет клетки там выбирается голосованием пикселей (дизеринг по градиентам —
  /// отдельная стадия T57).
  /// Стадия 4: сглаживание разметки по ценам цветов (T47). Работает только на пиксельном пути.
  final LabelSmoother? smoother;

  /// «Детально»: цвета, освободившиеся при слиянии и очистке, достаются следующему акценту (число цветов — верхняя граница).
  final bool refillFreedColors;

  /// Лица на фото (T54): отдельные цвета кожи, защита черт, зрачки и губы. Работает только на пиксельном пути; нужны
  /// `FaceAwarePaletteBuilder` и `FaceFeatureStep`. `null` — лиц нет или они не нужны.
  final FaceGuide? faces;

  /// Черновик для предпросмотра при движении ползунка (T58): рабочая картинка в [WorkImage.draftScale] пикселя на клетку.
  /// Такой результат показывают, но не сохраняют: после паузы мастер считает полный. Путь T24 черновик не знает.
  final bool draft;

  /// Тот же запрос на другой картинке (и маске): так изолят сессии подставляет картинку, которую уже получил.
  ImageToGridRequest withSource({required SourceImage image, Float32List? importance}) => ImageToGridRequest(
    image: image,
    geometry: geometry,
    metrics: metrics,
    columns: columns,
    rows: rows,
    maxColors: maxColors,
    constraint: constraint,
    importance: importance,
    dither: dither,
    seed: seed,
    prefilter: prefilter,
    paletteBuilder: paletteBuilder,
    labeler: labeler,
    smoother: smoother,
    refillFreedColors: refillFreedColors,
    faces: faces,
    draft: draft,
    steps: steps,
  );

  bool get usesPixelStages => paletteBuilder != null || labeler != null || smoother != null;

  /// Шаги после привязки к палитре, по порядку.
  final List<PatternStep> steps;
}
