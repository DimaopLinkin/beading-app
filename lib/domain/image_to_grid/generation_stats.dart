import 'package:equatable/equatable.dart';

/// Метрики готовой схемы: по ним мастер подсказывает пользователю, а галерея качества (T51) ловит ухудшения.
final class GenerationStats extends Equatable {
  GenerationStats({
    required this.singleCells,
    required this.colorCount,
    required this.meanDeltaE,
    required Map<String, Duration> stageTimes,
    this.singleCellsBefore,
    this.contrast,
    this.lightnessCorrelation,
  }) : stageTimes = Map<String, Duration>.unmodifiable(stageTimes);

  /// Клетки без единого соседа своего цвета («конфетти»); пустые клетки не считаются.
  final int singleCells;

  /// Одиночных клеток сразу после разметки, до сглаживания и очистки; `null`, если очистки не было.
  final int? singleCellsBefore;

  /// Сколько цветов осталось в схеме.
  final int colorCount;

  /// Средняя ΔE2000 между цветом клетки в схеме и средним цветом фото под ней (по непустым клеткам). Это цвет ячейки после выборки, а не отдельные пиксели фото.
  final double meanDeltaE;

  /// Контраст (T65): разброс светлоты схемы к разбросу светлоты фото по рабочим пикселям без подготовки фото; `null` в
  /// черновике и когда у фото нет разброса светлоты.
  final double? contrast;

  /// Корреляция светлоты схемы с фото (T65), см. [contrast].
  final double? lightnessCorrelation;

  /// Время стадий конвейера по названиям: `sample`, `palette`, `assign` (вместе с упорядочиванием палитры), `steps`; сам подсчёт метрик не входит.
  final Map<String, Duration> stageTimes;

  Duration get totalTime => stageTimes.values.fold(Duration.zero, (sum, d) => sum + d);

  @override
  List<Object?> get props => <Object?>[
    singleCells,
    singleCellsBefore,
    colorCount,
    meanDeltaE,
    contrast,
    lightnessCorrelation,
    stageTimes,
  ];
}
