import 'dart:typed_data';

import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/background_stage.dart';
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
    this.subjectMask,
    this.background = BackgroundMode.keep,
    this.outline = false,
    this.suggestBlends = false,
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
    final Uint8List? mask = subjectMask;
    if (mask != null && mask.length != image.width * image.height) {
      throw ArgumentError.value(mask.length, 'subjectMask', 'ожидалось ${image.width * image.height} значений');
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

  /// Дизеринг Флойда — Стейнберга по всей картинке; только путь T24. На пиксельном пути плавные переходы даёт шаг
  /// `OrderedDitherStep` (T57), и этот флаг не действует.
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

  /// Тот же запрос на другой картинке, маске важности, маске объекта и лицах: так изолят сессии подставляет то, что уже
  /// получил. Лица [faces] и маска объекта заменяются, `null` — без них.
  ImageToGridRequest withSource({
    required SourceImage image,
    Float32List? importance,
    FaceGuide? faces,
    Uint8List? subjectMask,
  }) => ImageToGridRequest(
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
    subjectMask: subjectMask,
    background: background,
    outline: outline,
    suggestBlends: suggestBlends,
  );

  /// Маска объекта (T55): значение на пиксель картинки, ряды сверху вниз; `0` — фон, остальное — объект. `null` — маски
  /// нет, и [background] с [outline] не действуют.
  final Uint8List? subjectMask;

  /// Что делать с фоном; действует только при [subjectMask].
  final BackgroundMode background;

  /// Обводка объекта одной клеткой тёмного цвета (бисер); действует только при [subjectMask].
  final bool outline;

  /// Искать бленды двух ниток (вышивка, T57): результат в `GeneratedPattern.blendSuggestions`.
  final bool suggestBlends;

  /// Тот же запрос с маской объекта, режимом фона и обводкой (маска, фон и обводка заменяются целиком).
  ImageToGridRequest withBackground({
    required Uint8List? mask,
    BackgroundMode mode = BackgroundMode.keep,
    bool outline = false,
  }) => ImageToGridRequest(
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
    subjectMask: mask,
    background: mode,
    outline: outline,
    suggestBlends: suggestBlends,
  );

  bool get usesBackgroundStage => subjectMask != null && (background != BackgroundMode.keep || outline);

  /// Важность пикселей с учётом фона: «убрать» почти не тратит цвета палитры на фон, «упростить» вдвое снижает его вес.
  Float32List? get effectiveImportance {
    final Uint8List? mask = subjectMask;
    if (mask == null || background == BackgroundMode.keep) return importance;
    final double factor = background == BackgroundMode.remove ? 0.05 : 0.5;
    final Float32List? base = importance;
    return Float32List.fromList(<double>[
      for (int i = 0; i < mask.length; i++) (base == null ? 1.0 : base[i]) * (mask[i] == 0 ? factor : 1),
    ]);
  }

  bool get usesPixelStages => paletteBuilder != null || labeler != null || smoother != null;

  /// Шаги после привязки к палитре, по порядку.
  final List<PatternStep> steps;
}
