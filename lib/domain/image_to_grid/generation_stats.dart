import 'package:equatable/equatable.dart';

/// Метрики готовой схемы: по ним мастер подсказывает пользователю, а галерея качества (T51) ловит ухудшения.
final class GenerationStats extends Equatable {
  GenerationStats({
    required this.singleCells,
    required this.colorCount,
    required this.meanDeltaE,
    required Map<String, Duration> stageTimes,
  }) : stageTimes = Map<String, Duration>.unmodifiable(stageTimes);

  /// Клетки без единого соседа своего цвета («конфетти»); пустые клетки не считаются.
  final int singleCells;

  /// Сколько цветов осталось в схеме.
  final int colorCount;

  /// Средняя ΔE2000 между цветом клетки в схеме и средним цветом фото под ней (по непустым клеткам).
  final double meanDeltaE;

  /// Время стадий конвейера по названиям: `sample`, `palette`, `assign`, `steps`.
  final Map<String, Duration> stageTimes;

  Duration get totalTime => stageTimes.values.fold(Duration.zero, (sum, d) => sum + d);

  @override
  List<Object?> get props => <Object?>[singleCells, colorCount, meanDeltaE, stageTimes];
}
