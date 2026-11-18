import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:equatable/equatable.dart';

/// Сколько бусин одного цвета нужно на инструкцию.
final class StepMaterialLine extends Equatable {
  const StepMaterialLine({required this.colorIndex, required this.color, required this.pieces});

  /// Индекс в [StepPattern.palette].
  final int colorIndex;
  final PatternColor color;
  final int pieces;

  @override
  List<Object?> get props => <Object?>[colorIndex, color, pieces];
}

/// Бусины инструкции: «число в шаге × повторы шага × повторы секции». Повтор «до нужной длины» считается
/// один раз, то есть расход на один повтор. Цвета, которых нет в шагах, в список не попадают.
abstract final class StepMaterials {
  static List<StepMaterialLine> of(StepPattern pattern) {
    final Map<int, int> pieces = <int, int>{};
    for (final StepSection section in pattern.sections) {
      for (final InstructionStep step in section.steps) {
        final int times = section.repeat.passes * step.repeat.passes;
        for (final StepBead bead in step.beads) {
          pieces[bead.colorIndex] = (pieces[bead.colorIndex] ?? 0) + bead.count * times;
        }
      }
    }
    final List<int> order = pieces.keys.where((i) => i >= 0 && i < pattern.palette.length).toList()..sort();
    return <StepMaterialLine>[
      for (final int i in order) StepMaterialLine(colorIndex: i, color: pattern.palette[i], pieces: pieces[i]!),
    ];
  }
}
