import 'package:beading/domain/image_to_grid/cleanup_steps.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
import 'package:beading/domain/image_to_grid/image_prefilter.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('порог островов растёт с размером схемы', () {
    for (final GenerationPreset p in GenerationPreset.values) {
      expect(p.minIslandFor(40), p.minIsland);
      expect(p.minIslandFor(100), p.minIsland + 1);
      expect(p.minIslandFor(150), p.minIsland + 2);
    }
  });

  test('предустановки: местный контраст только в «сбалансированно» и «детально», сильнее у «сбалансированно»', () {
    double contrast(GenerationPreset p) => (p.prefilter as EdgePreservingPrefilter).localContrast;
    expect(contrast(GenerationPreset.simpler), 0);
    expect(contrast(GenerationPreset.balanced), greaterThan(contrast(GenerationPreset.detailed)));
    expect(contrast(GenerationPreset.detailed), greaterThan(0));
  });

  test('вес заметности и контраст не складываются в «сбалансированно», вес — только в «детально»', () {
    expect(GenerationPreset.balanced.detailVoting, isFalse);
    expect(GenerationPreset.detailed.detailVoting, isTrue);
  });

  test('шаги очистки берут порог по размеру и оттенковую фактуру; диагонали защищены при голосовании', () {
    final List<PatternStep> steps = GenerationPreset.detailed.stepsFor(columns: 100);
    final RemoveIslandsStep islands = steps.first as RemoveIslandsStep;
    expect(islands.minIsland, 3);
    expect(islands.keepToneDeltaE, GenerationPreset.detailed.keepToneDeltaE);
    expect(islands.protectDiagonals, isTrue);
    expect((GenerationPreset.balanced.stepsFor(columns: 40).first as RemoveIslandsStep).protectDiagonals, isFalse);
  });

  test('дизеринг не включён ни в одной предустановке и по умолчанию', () {
    expect(const ImageToGridSettings().dither, isFalse);
    for (final GenerationPreset p in GenerationPreset.values) {
      expect(const ImageToGridSettings().copyWith(preset: p).dither, isFalse);
    }
  });
}
