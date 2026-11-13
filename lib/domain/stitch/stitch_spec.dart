import 'package:equatable/equatable.dart';

/// Число сложений нити: сколько ниток мулине в иголке для крестика и для бэкстича.
///
/// Схема хранит [StitchSpec] по умолчанию, а у отдельного цвета палитры может быть своё (см. `StitchLayers`).
final class StitchSpec extends Equatable {
  const StitchSpec({this.crossStrands = 2, this.backstitchStrands = 1})
    : assert(crossStrands >= minStrands && crossStrands <= maxStrands, 'сложения крестика: 1–6'),
      assert(backstitchStrands >= minStrands && backstitchStrands <= maxStrands, 'сложения бэкстича: 1–6');

  /// Значения по умолчанию для плотности канвы, крестиков на дюйм: Аида 11 — 3 сложения, до 18 — 2, плотнее — 1.
  /// Бэкстич — в одно сложение.
  factory StitchSpec.forDensity(double stitchesPerInch) =>
      StitchSpec(crossStrands: stitchesPerInch <= 11 ? 3 : (stitchesPerInch <= 18 ? 2 : 1));

  static const int minStrands = 1;
  static const int maxStrands = 6;

  final int crossStrands;
  final int backstitchStrands;

  StitchSpec copyWith({int? crossStrands, int? backstitchStrands}) => StitchSpec(
    crossStrands: crossStrands ?? this.crossStrands,
    backstitchStrands: backstitchStrands ?? this.backstitchStrands,
  );

  @override
  List<Object?> get props => <Object?>[crossStrands, backstitchStrands];
}
