import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:equatable/equatable.dart';

/// Одна проба подсказки: схема в [columns] клеток и [colors] цветов дала [correlation] светлоты с фото (T65).
final class SizeProbe extends Equatable {
  const SizeProbe({required this.columns, required this.colors, required this.correlation});

  final int columns;
  final int colors;

  /// `null` — у фото нет разброса светлоты, метрика не определена.
  final double? correlation;

  @override
  List<Object?> get props => <Object?>[columns, colors, correlation];
}

/// Подсказка «для этого фото лучше от N столбцов и K цветов».
final class SizeSuggestion extends Equatable {
  const SizeSuggestion({required this.columns, required this.colors, required this.reached});

  final int columns;
  final int colors;

  /// Порог корреляции достигнут; `false` — даже самая крупная проба его не дала, берётся она (фото очень мелкое
  /// по деталям: туманность, рукописный текст).
  final bool reached;

  @override
  List<Object?> get props => <Object?>[columns, colors, reached];
}

/// Подбор размера схемы по пробам.
///
/// Правило (T61, выбрано по таблице галереи): берётся самая узкая проба, у которой корреляция светлоты схемы с фото не
/// ниже [threshold] и ширина не меньше `minColumns`. Правило «прирост меньше 0,02 за шаг» не годится: для портрета оно
/// даёт 60 столбцов, для логотипа 120. Порог 0,90 даёт на галерее: пейзаж 40, кофе, логотип, портрет 60, ракета 80,
/// рисунок 100, кошка 120, а туманность и рукописный текст не доходят до порога и получают предел.
final class SizeSuggester {
  const SizeSuggester({this.threshold = 0.90});

  final double threshold;

  /// Ширины проб и число цветов для каждой по ремеслу; не шире [maxColumns].
  static List<({int columns, int colors})> candidates(Craft craft, {required int maxColumns}) {
    final List<({int columns, int colors})> all = craft == Craft.crossStitch
        ? <({int columns, int colors})>[
            for (final int c in stitchWidths) (columns: c, colors: stitchColors),
          ]
        : <({int columns, int colors})>[
            for (final int c in beadWidths) (columns: c, colors: (c ~/ 6).clamp(8, 20)),
          ];
    return <({int columns, int colors})>[
      for (final ({int columns, int colors}) c in all)
        if (c.columns <= maxColumns) c,
    ];
  }

  static const List<int> beadWidths = <int>[30, 40, 60, 80, 100, 120];

  /// Ширины проб для вышивки: диапазон 110–200 клеток по прогону Насти на реальных размерах (аида 14 и 18, 20–30 см).
  static const List<int> stitchWidths = <int>[110, 130, 150, 175, 200];
  static const int stitchColors = 30;

  /// Лучшая проба из [probes] или `null`, если ни у одной нет корреляции.
  SizeSuggestion? choose(List<SizeProbe> probes, {int minColumns = 0}) {
    final List<SizeProbe> ordered = <SizeProbe>[
      for (final SizeProbe p in probes)
        if (p.correlation != null) p,
    ]..sort((a, b) => a.columns.compareTo(b.columns));
    if (ordered.isEmpty) return null;
    for (final SizeProbe p in ordered) {
      if (p.columns >= minColumns && p.correlation! >= threshold) {
        return SizeSuggestion(columns: p.columns, colors: p.colors, reached: true);
      }
    }
    // Порог не достигнут: берём самую крупную пробу (но не уже минимума, если он выше всех).
    final SizeProbe last = ordered.last;
    return SizeSuggestion(columns: last.columns, colors: last.colors, reached: false);
  }

  /// Ширина подсказки в сантиметрах на заданной канве или бисере.
  static double centimetres(int columns, CellMetrics metrics) => columns * metrics.widthMm / 10;
}
