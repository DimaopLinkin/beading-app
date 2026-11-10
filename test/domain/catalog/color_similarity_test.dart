import 'package:beading/domain/catalog/color_similarity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('одинаковые цвета похожи на 100% и почти неотличимы', () {
    final ColorSimilarity s = ColorSimilarity(0);
    expect(s.percent, 100);
    expect(s.level, SimilarityLevel.nearlyIdentical);
  });

  test('проценты убывают линейно до нуля при ΔE 25', () {
    expect(ColorSimilarity(1).percent, 96);
    expect(ColorSimilarity(5).percent, 80);
    expect(ColorSimilarity(12.5).percent, 50);
    expect(ColorSimilarity(25).percent, 0);
    expect(ColorSimilarity(80).percent, 0);
  });

  test('уровни меняются на границах ΔE 1, 3 и 6', () {
    expect(ColorSimilarity(0.99).level, SimilarityLevel.nearlyIdentical);
    expect(ColorSimilarity(1).level, SimilarityLevel.veryClose);
    expect(ColorSimilarity(2.99).level, SimilarityLevel.veryClose);
    expect(ColorSimilarity(3).level, SimilarityLevel.close);
    expect(ColorSimilarity(5.99).level, SimilarityLevel.close);
    expect(ColorSimilarity(6).level, SimilarityLevel.noticeable);
  });

  test('отрицательное и нечисловое ΔE отвергается', () {
    expect(() => ColorSimilarity(-0.1), throwsArgumentError);
    expect(() => ColorSimilarity(double.nan), throwsArgumentError);
    expect(() => ColorSimilarity(double.infinity), throwsArgumentError);
  });
}
