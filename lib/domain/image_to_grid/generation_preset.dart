import 'package:beading/domain/image_to_grid/cleanup_steps.dart';
import 'package:beading/domain/image_to_grid/image_prefilter.dart';
import 'package:beading/domain/image_to_grid/label_smoother.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';

/// Предустановка генератора: один выбор вместо набора параметров всех стадий (T52–T47).
enum GenerationPreset {
  /// Крупные чистые области, мало деталей: проще вязать.
  simpler(
    prefilterSigma: 12,
    detail: 0.15,
    minIsland: 4,
    mergeDeltaE: 7,
    mergeArea: 0.03,
    refillFreedColors: false,
  ),

  /// Золотая середина; по умолчанию.
  balanced(prefilterSigma: 9, detail: 0.5, minIsland: 3, mergeDeltaE: 5, mergeArea: 0.02, refillFreedColors: false),

  /// Больше деталей и мелких акцентов, очистка осторожнее; освободившиеся цвета отдаются акцентам.
  detailed(prefilterSigma: 7, detail: 0.85, minIsland: 2, mergeDeltaE: 5, mergeArea: 0.02, refillFreedColors: true)
  ;

  const GenerationPreset({
    required this.prefilterSigma,
    required this.detail,
    required this.minIsland,
    required this.mergeDeltaE,
    required this.mergeArea,
    required this.refillFreedColors,
  });

  /// Стадия 1: насколько разные цвета ещё усредняются (Lab).
  final double prefilterSigma;

  /// Стадия 4: ползунок «гладко (0) ↔ детально (1)».
  final double detail;

  /// Стадия 5: области меньше этого числа клеток перекрашиваются.
  final int minIsland;

  /// Стадия 5: цвета ближе этого ΔE2000 сливаются, если меньший занимает меньше [mergeArea] схемы.
  final double mergeDeltaE;
  final double mergeArea;

  /// Отдавать освободившиеся цвета следующему акценту.
  final bool refillFreedColors;

  ImagePrefilter get prefilter => EdgePreservingPrefilter(sigmaRange: prefilterSigma);

  LabelSmoother get smoother => PottsLabelSmoother(detail: detail);

  /// Шаги очистки после разметки: острова, потом слияние.
  List<PatternStep> get steps => <PatternStep>[
    RemoveIslandsStep(minIsland: minIsland),
    MergeColorsStep(maxDeltaE: mergeDeltaE, maxArea: mergeArea),
  ];
}
