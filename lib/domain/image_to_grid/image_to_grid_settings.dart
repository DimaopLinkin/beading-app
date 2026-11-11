import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/background_stage.dart';
import 'package:beading/domain/image_to_grid/cell_labeler.dart';
import 'package:beading/domain/image_to_grid/cell_sampler.dart';
import 'package:beading/domain/image_to_grid/face_guide.dart';
import 'package:beading/domain/image_to_grid/face_palette_builder.dart';
import 'package:beading/domain/image_to_grid/face_step.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/ordered_dither_step.dart';
import 'package:beading/domain/image_to_grid/palette_builder.dart';
import 'package:beading/domain/image_to_grid/palette_constraint.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/technique_geometry.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:equatable/equatable.dart';

/// Откуда брать цвета схемы.
enum PaletteSource {
  /// Только позиции каталога бисера (выбранный бренд и размер): схему можно собрать из магазинных цветов.
  catalog,

  /// Любые цвета, выбранные по самой картинке.
  free,
}

/// Параметры мастера «Схема из картинки».
final class ImageToGridSettings extends Equatable {
  const ImageToGridSettings({
    this.technique = Technique.loom,
    this.beadSize = BeadSize.delica11,
    this.columns = defaultColumns,
    this.maxColors = defaultMaxColors,
    this.paletteSource = PaletteSource.catalog,
    this.dither = false,
    this.useMasks = true,
    this.preset = GenerationPreset.balanced,
    this.steps = const <PatternStep>[],
    this.background = BackgroundMode.keep,
    this.outline = false,
    this.fabric = Fabric.standard,
    this.backstitch = false,
    this.blends = false,
  });

  static const int defaultColumns = 40;
  static const int minColumns = 8;
  static const int maxColumns = 120;

  /// Вышивка большая: ориентир A09 — 110–200 крестиков по ширине (канва Аида 14, 20–30 см).
  static const int maxStitchColumns = 250;
  static const int defaultStitchColumns = 150;
  static const int defaultStitchColors = 30;
  static const int defaultMaxColors = 8;
  static const int minColors = 2;
  static const int maxColorsLimit = 30;

  /// Техники мастера для [craft].
  static List<Technique> techniquesOf(Craft craft) => craft.techniques;

  /// Самая большая ширина схемы в ячейках для [craft].
  static int maxColumnsOf(Craft craft) => craft == Craft.crossStitch ? maxStitchColumns : maxColumns;

  final Technique technique;
  final BeadSize beadSize;

  /// Канва для вышивки (T46): плотность, «через N» и цвет; размер крестика и фон схемы берутся из неё.
  final Fabric fabric;

  /// Контуры-бэкстич из картинки (T49, только вышивка).
  final bool backstitch;

  /// Заменить области «посередине» двух ниток блендом (T57, только вышивка).
  final bool blends;

  Craft get craft => technique.craft;

  /// Размер ячейки: бусина или крестик на канве.
  CellMetrics get metrics => craft == Craft.crossStitch ? fabric : beadSize;

  /// Ширина схемы в сантиметрах (вышивка).
  double get widthCm => fabric.cmForCells(columns);

  /// Ширина схемы в ячейках.
  final int columns;

  /// Сколько цветов в схеме самое большее.
  final int maxColors;
  final PaletteSource paletteSource;
  final bool dither;

  /// Учитывать лица и объект, найденные на фото (T48), как «важное». Без найденных масок ни на что не влияет.
  final bool useMasks;

  /// Предустановка стадий генератора: подготовка фото, палитра с акцентами, голосование, сглаживание и очистка.
  /// `null` — путь T24 без новых стадий (для сравнения и тестов).
  final GenerationPreset? preset;

  /// Дополнительные шаги после очистки предустановки (контуры, слои): расширение для T49 и дальше.
  final List<PatternStep> steps;

  /// Палитра для черновика: выборка пикселей и итераций вдвое-вчетверо меньше, цвета чуть грубее, расчёт быстрее.
  static const AccentPaletteBuilder draftPaletteBuilder = AccentPaletteBuilder(sampleSize: 5000, iterations: 10);
  static const FaceAwarePaletteBuilder draftFacePaletteBuilder = FaceAwarePaletteBuilder(inner: draftPaletteBuilder);

  /// Что делать с фоном: действует, только если у мастера есть маска объекта (T48); без неё настройку не показывают.
  final BackgroundMode background;

  /// Обводка объекта одной клеткой тёмного цвета (только бисер, нужна маска объекта).
  final bool outline;

  GridGeometry get geometry => geometryForTechnique(technique);

  ImageToGridSettings copyWith({
    Technique? technique,
    BeadSize? beadSize,
    int? columns,
    int? maxColors,
    PaletteSource? paletteSource,
    bool? dither,
    bool? useMasks,
    GenerationPreset? preset,
    bool clearPreset = false,
    List<PatternStep>? steps,
    BackgroundMode? background,
    bool? outline,
    Fabric? fabric,
    bool? backstitch,
    bool? blends,
  }) => ImageToGridSettings(
    technique: technique ?? this.technique,
    beadSize: beadSize ?? this.beadSize,
    columns: (columns ?? this.columns).clamp(minColumns, maxColumnsOf((technique ?? this.technique).craft)),
    maxColors: (maxColors ?? this.maxColors).clamp(minColors, maxColorsLimit),
    paletteSource: paletteSource ?? this.paletteSource,
    dither: dither ?? this.dither,
    useMasks: useMasks ?? this.useMasks,
    preset: clearPreset ? null : preset ?? this.preset,
    steps: steps ?? this.steps,
    background: background ?? this.background,
    outline: outline ?? this.outline,
    fabric: fabric ?? this.fabric,
    backstitch: backstitch ?? this.backstitch,
    blends: blends ?? this.blends,
  );

  /// Число рядов, при котором схема повторяет пропорции [image].
  int rowsFor(SourceImage image) => math.min(
    Grid.maxSide,
    GridSizing.rowsForColumns(
      imageWidth: image.width,
      imageHeight: image.height,
      geometry: geometry,
      metrics: metrics,
      columns: columns,
    ),
  );

  /// Материал каталога под ремесло: бисер или мулине.
  CatalogMaterial get material => craft == Craft.crossStitch ? CatalogMaterial.floss : CatalogMaterial.bead;

  /// Подходящие под ремесло, размер бисера и бренд позиции [catalog]; [brand] пустой — любой бренд.
  /// У мулине размера нет: годится любая позиция бренда.
  List<CatalogColor> catalogFor(List<CatalogColor> catalog, {String brand = ''}) => <CatalogColor>[
    for (final CatalogColor color in catalog)
      if (color.material == material &&
          (brand.isEmpty || color.brand == brand) &&
          (craft == Craft.crossStitch || color.sizeCode == beadSize.sizeCode))
        color,
  ];

  /// Запрос к конвейеру. Если каталожных цветов под размер и бренд нет, палитра выбирается свободно.
  ImageToGridRequest toRequest({
    required SourceImage image,
    List<CatalogColor> catalog = const <CatalogColor>[],
    String brand = '',
    Float32List? importance,
    ImageMaskSet? masks,
    int seed = 0,
    bool draft = false,
    Uint8List? subjectMask,
  }) {
    final List<CatalogColor> allowed = catalogFor(catalog, brand: brand);
    final bool useCatalog = paletteSource == PaletteSource.catalog && allowed.isNotEmpty;
    // «Плавные переходы» с предустановкой — упорядоченный дизеринг только в градиентах последним шагом (T57); без
    // предустановки остаётся путь T24 с Флойдом — Стейнбергом.
    final GenerationPreset? active = preset;
    // Лица (T54): отдельные цвета кожи и защита черт; без лиц на фото поведение прежнее.
    final FaceGuide? faceGuide = active == null || masks == null || masks.faces.isEmpty ? null : FaceGuide(masks);
    return ImageToGridRequest(
      image: image,
      geometry: geometry,
      // Цвет канвы расчёт не меняет: метрики без него, чтобы его смена не сбрасывала кеш стадий (T58).
      metrics: craft == Craft.crossStitch ? fabric.withColor(const Rgb(255, 255, 255)) : metrics,
      columns: columns,
      rows: rowsFor(image),
      maxColors: maxColors,
      constraint: useCatalog ? PaletteConstraint.catalog(allowed, material: material) : const PaletteConstraint.free(),
      importance: importance,
      dither: dither && active == null,
      seed: seed,
      prefilter: active?.prefilter,
      paletteBuilder: active == null
          ? null
          : faceGuide == null
          ? (draft ? draftPaletteBuilder : const AccentPaletteBuilder())
          : (draft ? draftFacePaletteBuilder : const FaceAwarePaletteBuilder()),
      labeler: active == null ? null : const VotingCellLabeler(),
      smoother: active?.smoother,
      refillFreedColors: active?.refillFreedColors ?? false,
      faces: faceGuide,
      draft: draft,
      steps: <PatternStep>[
        ...?active?.steps,
        if (faceGuide != null) const FaceFeatureStep(),
        ...steps,
        if (dither && active != null) const OrderedDitherStep(),
      ],
      subjectMask: subjectMask,
      background: background,
      // Обводка одной бусиной — для бисера; у вышивки контуры — бэкстич (T49).
      outline: outline && craft == Craft.beading,
      suggestBlends: craft == Craft.crossStitch,
      applyBlends: craft == Craft.crossStitch && blends && useCatalog,
      // Контуры строятся по рабочей картинке пиксельного пути: без предустановки их нет.
      backstitch: craft == Craft.crossStitch && backstitch && active != null,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    technique,
    beadSize,
    columns,
    maxColors,
    paletteSource,
    dither,
    useMasks,
    preset,
    steps,
    background,
    outline,
    fabric,
    backstitch,
    blends,
  ];
}
