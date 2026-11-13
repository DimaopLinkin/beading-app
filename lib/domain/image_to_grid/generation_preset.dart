import 'package:beading/domain/image_to_grid/cleanup_steps.dart';
import 'package:beading/domain/image_to_grid/image_prefilter.dart';
import 'package:beading/domain/image_to_grid/label_smoother.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';

/// Предустановка генератора: один выбор вместо набора параметров всех стадий (T52–T47, вторая версия — T66).
///
/// Подобрана по галерее качества (`gallery/T66` в папке проекта): контраст в среднем 0,92–1,08, корреляция светлоты не
/// хуже первой версии, одиночных клеток не больше ×1,3 у «сбалансированно». Дизеринг ни в одной предустановке не включён.
enum GenerationPreset {
  /// Крупные чистые области, мало деталей: проще вязать.
  simpler(
    prefilterSigma: 12,
    localContrast: 0,
    detail: 0.15,
    minIsland: 4,
    keepToneDeltaE: 0,
    mergeDeltaE: 7,
    mergeArea: 0.03,
    refillFreedColors: false,
    detailVoting: false,
  ),

  /// Золотая середина, ближе к простому T24: свет и тени не «выцветают» (местный контраст), одиночные клетки близких
  /// оттенков остаются как фактура, чужие убираются. Вес заметности (T64) не включён: вместе с контрастом он даёт кайму.
  balanced(
    prefilterSigma: 9,
    localContrast: 0.5,
    detail: 0.5,
    minIsland: 3,
    keepToneDeltaE: 3,
    mergeDeltaE: 5,
    mergeArea: 0.02,
    refillFreedColors: false,
    detailVoting: false,
  ),

  /// По умолчанию (выбор Дмитрия на листах T66). Больше деталей, фактуры и мелких акцентов: вес заметности, мягкая очистка, освободившиеся цвета отдаются акцентам.
  /// Местный контраст слабее, чтобы вес заметности и контраст не складывались на одном крае.
  detailed(
    prefilterSigma: 7,
    localContrast: 0.35,
    detail: 0.85,
    minIsland: 2,
    keepToneDeltaE: 8,
    mergeDeltaE: 5,
    mergeArea: 0.02,
    refillFreedColors: true,
    detailVoting: true,
  )
  ;

  const GenerationPreset({
    required this.prefilterSigma,
    required this.localContrast,
    required this.detail,
    required this.minIsland,
    required this.keepToneDeltaE,
    required this.mergeDeltaE,
    required this.mergeArea,
    required this.refillFreedColors,
    required this.detailVoting,
  });

  /// Стадия 1: насколько разные цвета ещё усредняются (Lab).
  final double prefilterSigma;

  /// Стадия 1: местный контраст (T63), доля разницы с размытой копией; 0 — выключен.
  final double localContrast;

  /// Стадия 4: ползунок «гладко (0) ↔ детально (1)».
  final double detail;

  /// Стадия 5: области меньше этого числа клеток перекрашиваются (для схемы в 60 столбцов).
  final int minIsland;

  /// Стадия 5: остров близкого оттенка (ΔE2000 до цвета, куда его пришлось бы перекрасить, не больше этого) остаётся
  /// как фактура; чужие по тону убираются. 0 — убираются все.
  final double keepToneDeltaE;

  /// Стадия 5: цвета ближе этого ΔE2000 сливаются, если меньший занимает меньше [mergeArea] схемы.
  final double mergeDeltaE;
  final double mergeArea;

  /// Отдавать освободившиеся цвета следующему акценту.
  final bool refillFreedColors;

  /// Голосование клетки с весом заметности и защита диагональных линий (T64).
  final bool detailVoting;

  ImagePrefilter get prefilter => EdgePreservingPrefilter(sigmaRange: prefilterSigma, localContrast: localContrast);

  LabelSmoother get smoother => PottsLabelSmoother(detail: detail);

  /// Порог островов для схемы в [columns] столбцов: на большой схеме одиночных клеток в разы больше, очистка сильнее.
  int minIslandFor(int columns) => minIsland + (columns >= 90 ? 1 : 0) + (columns >= 140 ? 1 : 0);

  /// Шаги очистки после разметки: острова, потом слияние.
  List<PatternStep> stepsFor({required int columns, bool? voting}) => <PatternStep>[
    RemoveIslandsStep(
      minIsland: minIslandFor(columns),
      keepToneDeltaE: keepToneDeltaE,
    ).withDiagonals(value: voting ?? detailVoting),
    MergeColorsStep(maxDeltaE: mergeDeltaE, maxArea: mergeArea),
  ];
}
