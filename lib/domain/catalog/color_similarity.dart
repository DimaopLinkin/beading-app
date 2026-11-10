import 'package:equatable/equatable.dart';

/// Словесная оценка похожести двух цветов по ΔE2000.
enum SimilarityLevel {
  /// ΔE < 1: глазом не отличить.
  nearlyIdentical,

  /// ΔE < 3: рядом их различит только внимательный взгляд.
  veryClose,

  /// ΔE < 6: заметно, если положить бусины рядом.
  close,

  /// Остальное: это уже другой оттенок.
  noticeable,
}

/// Мера похожести двух цветов для показа пользовательнице: проценты и словесный уровень.
///
/// Это шкала для людей, а не колориметрический стандарт: проценты линейно убывают от 100% при ΔE = 0 до 0% при
/// ΔE = [zeroPercentDeltaE]. Порог «неразличимо» (ΔE ≈ 1) попадает на 96%, «заметно» (ΔE ≈ 5) — на 80%.
final class ColorSimilarity extends Equatable {
  /// [deltaE] — расстояние ΔE2000, не меньше нуля.
  ColorSimilarity(this.deltaE) {
    if (!deltaE.isFinite || deltaE < 0) {
      throw ArgumentError.value(deltaE, 'deltaE', 'ΔE — конечное число не меньше нуля');
    }
  }

  /// ΔE2000, при котором похожесть падает до нуля.
  static const double zeroPercentDeltaE = 25;

  final double deltaE;

  /// Целые проценты от 0 до 100.
  int get percent => (100 * (1 - deltaE / zeroPercentDeltaE)).clamp(0, 100).round();

  SimilarityLevel get level {
    if (deltaE < 1) return SimilarityLevel.nearlyIdentical;
    if (deltaE < 3) return SimilarityLevel.veryClose;
    if (deltaE < 6) return SimilarityLevel.close;
    return SimilarityLevel.noticeable;
  }

  @override
  List<Object?> get props => <Object?>[deltaE];
}
