import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:equatable/equatable.dart';

/// Вид канвы для вышивки крестиком.
enum FabricKind {
  /// Аида: плотность — клеток на дюйм (11–20), один стежок на клетку.
  aida,

  /// Равномерка: плотность — нитей на дюйм (25–36), стежок «через 1» или «через 2» нити.
  evenweave,

  /// Лён: как равномерка, но нить неровная.
  linen,
}

/// Канва: плотность, вид, «через N» и цвет. Реализует [CellMetrics]: клетка схемы — один крестик.
///
/// Крестик на канве квадратный: ширина и высота клетки равны `25,4 мм * overCount / count`
/// ([ADR-0003](../../../docs/decisions/0003-crafts-in-domain.md)).
final class Fabric extends Equatable implements CellMetrics {
  const Fabric._({required this.kind, required this.count, required this.overCount, required this.color});

  static const double mmPerInch = 25.4;

  static const int aidaMinCount = 11;
  static const int aidaMaxCount = 20;
  static const int threadedMinCount = 25;
  static const int threadedMaxCount = 36;

  /// Канва по умолчанию — Аида 14 на белом: самая частая в наборах.
  static const Fabric standard = Fabric._(kind: FabricKind.aida, count: 14, overCount: 1, color: Rgb(255, 255, 255));

  /// [overCount] по умолчанию: 1 для Аиды, 2 для равномерки и льна.
  static Result<Fabric> create({
    required FabricKind kind,
    required int count,
    int? overCount,
    Rgb color = const Rgb(255, 255, 255),
  }) {
    final bool aida = kind == FabricKind.aida;
    final int over = overCount ?? (aida ? 1 : 2);
    if (aida) {
      if (count < aidaMinCount || count > aidaMaxCount) {
        return const Err<Fabric>(ValidationFailure('Плотность Аиды — от 11 до 20 клеток на дюйм'));
      }
      if (over != 1) {
        return const Err<Fabric>(ValidationFailure('На Аиде крестик — «через 1» клетку'));
      }
    } else {
      if (count < threadedMinCount || count > threadedMaxCount) {
        return const Err<Fabric>(ValidationFailure('Плотность равномерки и льна — от 25 до 36 нитей на дюйм'));
      }
      if (over != 1 && over != 2) {
        return const Err<Fabric>(ValidationFailure('Крестик ставят «через 1» или «через 2» нити'));
      }
    }
    return Success<Fabric>(Fabric._(kind: kind, count: count, overCount: over, color: color));
  }

  final FabricKind kind;

  /// Клеток (Аида) или нитей (равномерка, лён) на дюйм.
  final int count;

  /// Сколько нитей канвы занимает крестик по стороне (у Аиды всегда 1).
  final int overCount;

  /// Цвет канвы: фон схемы.
  final Rgb color;

  /// Крестиков на дюйм: то, что определяет размер схемы.
  double get stitchesPerInch => count / overCount;

  @override
  double get widthMm => mmPerInch * overCount / count;

  @override
  double get heightMm => widthMm;

  /// Сколько клеток помещается на [cm] сантиметров (не меньше одной).
  int cellsForCm(double cm) {
    _requirePositive(cm, 'cm');
    final int cells = (cm * 10 / widthMm).round();
    return cells < 1 ? 1 : cells;
  }

  /// Длина [cells] клеток в сантиметрах.
  double cmForCells(int cells) {
    if (cells <= 0) {
      throw ArgumentError.value(cells, 'cells', 'число клеток должно быть положительным');
    }
    return cells * widthMm / 10;
  }

  /// Сколько ниток мулине в иголке для крестика по умолчанию (зависит от крупности клетки).
  int get defaultCrossStrands {
    if (stitchesPerInch <= 11) return 3;
    if (stitchesPerInch <= 18) return 2;
    return 1;
  }

  /// Сколько ниток в иголке для бэкстича по умолчанию.
  int get defaultBackstitchStrands => stitchesPerInch <= 11 ? 2 : 1;

  Fabric withColor(Rgb newColor) => Fabric._(kind: kind, count: count, overCount: overCount, color: newColor);

  static void _requirePositive(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, name, 'размер должен быть положительным числом');
    }
  }

  @override
  List<Object?> get props => <Object?>[kind, count, overCount, color];

  @override
  String toString() => 'Fabric(${kind.name} $count через $overCount)';
}
